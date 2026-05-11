<template>
  <div>
    <PageHeader v-if="!editing" title="Journeys" subtitle="Multi-step automated flows triggered by events.">
      <template #actions>
        <button v-if="role.can('journeys', 'create')" @click="openPicker = true" class="btn-secondary"><Icon name="layers"/>From template</button>
        <button v-if="role.can('journeys', 'create')" @click="startBlank" class="btn-primary"><Icon name="plus"/>New journey</button>
        <div v-if="!role.can('journeys', 'create')" class="chip bg-ink-100 text-ink-700 text-xs">View only</div>
      </template>
    </PageHeader>

    <div v-if="!editing" class="p-8 space-y-4">
      <TestModeStrip what="Journeys" message="Journeys activated in test mode simulate flows but never deliver real messages to customers. Use this space to validate branches, delays, and triggers before going live."/>
      <ChannelReadiness :channels="['email','push']"/>
      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="j in journeys" :key="j.id" class="card p-5 hover:shadow-md cursor-pointer" @click="openJourney(j)">
        <div class="flex items-start justify-between mb-3">
          <div class="w-10 h-10 rounded-lg bg-brand-100/40 text-brand-500 flex items-center justify-center"><Icon name="route"/></div>
          <span class="chip" :class="j.status === 'active' ? 'bg-accent-500/10 text-accent-500' : j.status === 'paused' ? 'bg-yellow-100 text-yellow-700' : 'bg-ink-100 text-ink-700'">{{ j.status }}</span>
        </div>
        <div class="font-semibold text-ink-900">{{ j.name }}</div>
        <div class="text-xs text-ink-500 mt-1">Trigger: <span class="font-mono">{{ j.trigger_event || 'manual' }}</span></div>
        <div class="text-xs text-ink-500">{{ (j.nodes || []).length }} nodes</div>
        <div class="mt-4 pt-4 border-t border-ink-100 grid grid-cols-3 gap-2 text-center">
          <div><div class="text-lg font-bold text-ink-900">{{ j.entered_count }}</div><div class="text-[10px] text-ink-500">entered</div></div>
          <div><div class="text-lg font-bold text-brand-500">{{ activeCount(j) }}</div><div class="text-[10px] text-ink-500">active</div></div>
          <div><div class="text-lg font-bold text-accent-500">{{ j.completed_count }}</div><div class="text-[10px] text-ink-500">completed</div></div>
        </div>
      </div>
      <button @click="openPicker = true" class="card p-5 border-dashed flex flex-col items-center justify-center text-ink-500 hover:text-brand-500 hover:border-brand-500 min-h-[220px]">
        <Icon name="plus"/><div class="mt-2 text-sm font-medium">Create journey</div>
      </button>
      </div>
    </div>

    <div v-else class="fixed inset-0 bg-white z-50 flex flex-col">
      <div class="border-b border-ink-100 px-6 py-3 flex items-center justify-between shrink-0 bg-white">
        <div class="flex items-center gap-3">
          <button @click="closeEditor" class="text-ink-500 hover:text-ink-900"><Icon name="x"/></button>
          <div class="flex items-center gap-2">
            <input v-model="form.name" class="font-bold text-lg text-ink-900 bg-transparent border-0 focus:outline-none focus:bg-ink-50 rounded px-2 py-1"/>
            <Icon name="edit" class="w-4 h-4 text-ink-300"/>
          </div>
          <span class="chip" :class="form.status === 'active' ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ form.status }}</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="text-xs text-ink-500 mr-2">
            <span v-if="editing.id">ID: {{ editing.id.slice(0,8) }} · </span>
            <span v-if="lastSavedAt">Last saved {{ timeAgo(lastSavedAt) }}</span>
          </div>
          <button @click="saveDraft" class="btn-secondary">Finish later</button>
          <button v-if="role.can('journeys', 'activate')" @click="publish" class="btn-primary">{{ form.status === 'active' ? 'Save' : 'Publish journey' }}</button>
          <button v-else @click="askJourneyApproval" :disabled="requestingApproval" class="btn-primary"><Icon name="shield"/>{{ requestingApproval ? 'Requesting…' : 'Request approval' }}</button>
        </div>
      </div>

      <div class="border-b border-ink-100 px-6 py-2 flex items-center justify-between shrink-0 bg-white text-sm">
        <div class="flex items-center gap-3">
          <button @click="goalOpen = true" class="btn-ghost text-xs"><Icon name="trending"/>{{ form.goal?.event ? `Goal: ${form.goal.event}` : 'Add journey goal' }}</button>
          <div class="text-xs text-ink-500">
            <span v-if="form.trigger_event">Trigger: <span class="font-mono">{{ form.trigger_event }}</span></span>
            <span v-else>No trigger configured</span>
          </div>
        </div>
        <div class="flex items-center gap-1">
          <button @click="zoom = Math.max(0.4, zoom - 0.1)" class="btn-ghost px-2 text-xs">−</button>
          <div class="text-xs text-ink-500 w-12 text-center">{{ Math.round(zoom * 100) }}%</div>
          <button @click="zoom = Math.min(1.6, zoom + 0.1)" class="btn-ghost px-2 text-xs">+</button>
          <button @click="fitToScreen" class="btn-ghost px-2 text-xs">Fit</button>
          <button @click="showStats = !showStats" class="btn-ghost px-2 text-xs ml-2" :class="showStats ? 'text-accent-500' : ''"><Icon name="activity" class="w-3 h-3"/>{{ showStats ? 'Hide stats' : 'Show stats' }}</button>
        </div>
      </div>

      <div class="flex-1 flex overflow-hidden">
        <aside class="w-64 border-r border-ink-100 bg-white shrink-0 overflow-y-auto">
          <div v-for="(group, gi) in blockGroups" :key="gi" class="border-b border-ink-100">
            <button @click="group.open = !group.open" class="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-ink-50">
              <span class="text-sm font-semibold text-ink-900">{{ group.label }}</span>
              <Icon :name="group.open ? 'chevronDown' : 'chevronRight'" class="w-4 h-4 text-ink-500"/>
            </button>
            <div v-if="group.open" class="grid grid-cols-3 gap-2 p-3 pt-0">
              <div v-for="b in group.blocks" :key="b.kind"
                draggable="true"
                @dragstart="onDragStart($event, group.type, b)"
                class="flex flex-col items-center gap-1 p-2 rounded-lg border border-ink-100 hover:border-brand-500 hover:bg-brand-100/20 cursor-grab active:cursor-grabbing transition">
                <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="blockColor(group.type)">
                  <Icon :name="b.icon" class="w-5 h-5"/>
                </div>
                <div class="text-[10px] font-medium text-ink-700 text-center leading-tight">{{ b.label }}</div>
              </div>
            </div>
          </div>
        </aside>

        <div
          ref="canvasRef"
          class="flex-1 relative overflow-auto bg-brand-100/10"
          @dragover.prevent
          @drop="onCanvasDrop"
          @mousedown="startPan"
          @mousemove="onPan"
          @mouseup="stopPan"
          @mouseleave="stopPan"
        >
          <div class="absolute inset-0 pointer-events-none"
            style="background-image: radial-gradient(circle, rgba(48,135,185,0.15) 1px, transparent 1px); background-size: 24px 24px;"></div>

          <div
            ref="worldRef"
            class="absolute top-0 left-0"
            :style="{ width: '3000px', height: '2000px', transform: `scale(${zoom})`, transformOrigin: '0 0' }">

            <svg class="absolute top-0 left-0 pointer-events-none" width="3000" height="2000">
              <defs>
                <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">
                  <path d="M0,0 L10,5 L0,10 z" fill="#3087B9"/>
                </marker>
              </defs>
              <path v-for="(e, i) in edgePaths" :key="i" :d="e" stroke="#3087B9" stroke-width="2" fill="none" marker-end="url(#arrow)"/>
              <path v-if="connectingFrom && connectMouse" :d="previewPath" stroke="#26C165" stroke-width="2" fill="none" stroke-dasharray="4 4"/>
            </svg>

            <div v-if="!form.nodes.length" class="absolute" :style="{ left: '520px', top: '260px' }">
              <div class="bg-white border border-ink-100 rounded-xl shadow-soft px-8 py-6 text-center">
                <Icon name="route" class="w-8 h-8 mx-auto text-brand-500 mb-2"/>
                <div class="font-semibold text-ink-900">Start with Trigger!</div>
                <div class="text-xs text-ink-500 mt-1">Drag a trigger block from the left to begin.</div>
              </div>
            </div>

            <div v-for="n in form.nodes" :key="n.id"
              class="absolute group"
              :style="{ left: n.x + 'px', top: n.y + 'px' }"
              @mousedown.stop="startDragNode(n, $event)">
              <div
                class="w-52 rounded-xl border-2 bg-white shadow-soft cursor-move transition overflow-hidden"
                :class="[nodeBorder(n), selectedId === n.id ? 'ring-2 ring-brand-500 ring-offset-2' : '']"
                @click.stop="selectedId = n.id">
                <div class="flex items-center gap-2 px-3 py-2" :class="nodeHeaderBg(n)">
                  <div class="w-7 h-7 rounded-lg bg-white/90 flex items-center justify-center">
                    <Icon :name="nodeIcon(n)" class="w-4 h-4" :class="nodeIconColor(n)"/>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="text-[10px] font-semibold uppercase tracking-wider opacity-80">{{ n.type }}</div>
                    <div class="text-sm font-semibold truncate">{{ nodeTitle(n) }}</div>
                  </div>
                  <button @click.stop="removeNode(n)" class="opacity-0 group-hover:opacity-100 text-white/80 hover:text-white"><Icon name="x" class="w-3 h-3"/></button>
                </div>
                <div class="px-3 py-2 text-xs text-ink-500 min-h-[36px]">
                  {{ nodeSubtitle(n) }}
                </div>
                <div v-if="showStats && nodeStatsMap[n.id]" class="px-3 py-1.5 border-t border-ink-100 bg-ink-50 flex items-center justify-between text-[10px]">
                  <span class="text-ink-500">In <span class="font-semibold text-ink-900">{{ nodeStatsMap[n.id].entered_count }}</span></span>
                  <span class="text-ink-500">Done <span class="font-semibold text-accent-500">{{ nodeStatsMap[n.id].completed_count }}</span></span>
                  <span class="text-ink-500">Drop <span class="font-semibold text-red-600">{{ dropFor(n.id) }}%</span></span>
                </div>
                <div v-if="showStats && n.kind === 'ab_split' && abStatsMap[n.id]" class="px-3 py-1.5 border-t border-ink-100 bg-white text-[10px] grid grid-cols-2 gap-1">
                  <div class="text-center"><div class="font-semibold text-ink-900">A</div><div class="text-ink-500">{{ abStatsMap[n.id].a || 0 }} · {{ abConvPct(n.id, 'a') }}%</div></div>
                  <div class="text-center"><div class="font-semibold text-ink-900">B</div><div class="text-ink-500">{{ abStatsMap[n.id].b || 0 }} · {{ abConvPct(n.id, 'b') }}%</div></div>
                </div>
              </div>
              <button
                class="absolute -right-3 top-1/2 -translate-y-1/2 w-6 h-6 rounded-full bg-brand-500 text-white flex items-center justify-center hover:bg-brand-700 shadow-soft"
                title="Drag to connect"
                @mousedown.stop="startConnect(n, $event)">
                <Icon name="plus" class="w-3 h-3"/>
              </button>
              <div
                class="absolute -left-3 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full border-2 border-brand-500 bg-white"
                @mouseup.stop="completeConnect(n)"
              ></div>
            </div>
          </div>
        </div>

        <aside v-if="selectedNode" class="w-80 border-l border-ink-100 bg-white shrink-0 overflow-y-auto">
          <div class="px-5 py-4 border-b border-ink-100 flex items-center justify-between">
            <div>
              <div class="text-[10px] font-semibold text-ink-500 uppercase tracking-wider">{{ selectedNode.type }}</div>
              <div class="font-semibold text-ink-900">{{ nodeTitle(selectedNode) }}</div>
            </div>
            <button @click="selectedId = ''" class="text-ink-500 hover:text-ink-900"><Icon name="x"/></button>
          </div>
          <div class="p-5 space-y-3">
            <template v-if="selectedNode.type === 'trigger' && selectedNode.kind === 'activity'">
              <div><label class="label">Event</label>
                <select v-model="selectedNode.data.event" @change="onTriggerChange" class="input">
                  <option value="">— choose —</option>
                  <option v-for="d in eventDefs" :key="d.id" :value="d.name">{{ d.name }}</option>
                </select>
              </div>
              <div class="text-xs text-ink-500">Customers who do this event will enter the journey.</div>
            </template>
            <template v-else-if="selectedNode.type === 'trigger' && selectedNode.kind === 'segment'">
              <div><label class="label">Segment</label>
                <select v-model="selectedNode.data.segment_id" class="input">
                  <option value="">— choose —</option>
                  <option v-for="s in segments" :key="s.id" :value="s.id">{{ s.name }}</option>
                </select>
              </div>
            </template>
            <template v-else-if="selectedNode.type === 'trigger' && selectedNode.kind === 'list'">
              <div><label class="label">List</label>
                <select v-model="selectedNode.data.list_id" class="input">
                  <option value="">— choose —</option>
                  <option v-for="l in lists" :key="l.id" :value="l.id">{{ l.name }}</option>
                </select>
              </div>
            </template>

            <template v-else-if="['email','push','sms','whatsapp'].includes(selectedNode.kind)">
              <div><label class="label">Template</label>
                <select v-model="selectedNode.data.template_id" @change="applyTemplate(selectedNode)" class="input">
                  <option value="">— custom —</option>
                  <option v-for="t in channelTemplates(selectedNode.kind)" :key="t.id" :value="t.id">{{ t.name }}</option>
                </select>
              </div>
              <div v-if="selectedNode.kind === 'email'"><label class="label">Subject</label><input v-model="selectedNode.data.subject" class="input"/></div>
              <div><label class="label">{{ selectedNode.kind === 'email' ? 'Body' : 'Message' }}</label><textarea v-model="selectedNode.data.body" rows="4" class="input"></textarea></div>
            </template>

            <template v-else-if="selectedNode.kind === 'wait'">
              <div class="grid grid-cols-2 gap-2">
                <div><label class="label">Duration</label><input v-model.number="selectedNode.data.value" type="number" min="1" class="input"/></div>
                <div><label class="label">Unit</label>
                  <select v-model="selectedNode.data.unit" class="input">
                    <option>minutes</option><option>hours</option><option>days</option>
                  </select>
                </div>
              </div>
            </template>

            <template v-else-if="selectedNode.type === 'condition'">
              <div><label class="label">Field</label>
                <select v-model="selectedNode.data.field" class="input">
                  <option value="country">country</option><option value="platform">platform</option>
                  <option value="city">city</option><option value="device">device</option>
                </select>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <div><label class="label">Operator</label>
                  <select v-model="selectedNode.data.op" class="input">
                    <option value="eq">equals</option><option value="neq">not equal</option>
                    <option value="contains">contains</option>
                  </select>
                </div>
                <div><label class="label">Value</label><input v-model="selectedNode.data.value" class="input"/></div>
              </div>
            </template>

            <template v-else-if="selectedNode.kind === 'update_attribute'">
              <div><label class="label">Attribute key</label>
                <input v-model="selectedNode.data.attr_key" class="input" placeholder="e.g. lifecycle_stage"/>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <div><label class="label">Operation</label>
                  <select v-model="selectedNode.data.op" class="input">
                    <option value="set">Set</option>
                    <option value="increment">Increment (number)</option>
                    <option value="append">Append to list</option>
                  </select>
                </div>
                <div><label class="label">Value</label>
                  <input v-model="selectedNode.data.value" class="input" placeholder="engaged / 1 / vip"/>
                </div>
              </div>
              <div class="text-xs text-ink-500">Writes into <code class="bg-ink-50 px-1 rounded">customers.attributes</code> when this step runs.</div>
            </template>

            <template v-else-if="selectedNode.kind === 'wait_until_event'">
              <div><label class="label">Event</label>
                <select v-model="selectedNode.data.event" class="input">
                  <option value="">— choose —</option>
                  <option v-for="d in eventDefs" :key="d.id" :value="d.name">{{ d.name }}</option>
                </select>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <div><label class="label">Max wait</label><input v-model.number="selectedNode.data.max_value" type="number" min="1" class="input"/></div>
                <div><label class="label">Unit</label>
                  <select v-model="selectedNode.data.max_unit" class="input">
                    <option>minutes</option><option>hours</option><option>days</option>
                  </select>
                </div>
              </div>
              <div class="text-xs text-ink-500">Pauses each customer until the event fires or the window elapses.</div>
            </template>

            <template v-else-if="selectedNode.kind === 'condition'">
              <div><label class="label">Field</label>
                <input v-model="selectedNode.data.field" class="input" placeholder="country, attributes.plan, device"/>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <div><label class="label">Operator</label>
                  <select v-model="selectedNode.data.op" class="input">
                    <option value="eq">equals</option>
                    <option value="neq">not equal</option>
                    <option value="gt">greater than</option>
                    <option value="lt">less than</option>
                    <option value="contains">contains</option>
                    <option value="exists">exists</option>
                  </select>
                </div>
                <div><label class="label">Value</label><input v-model="selectedNode.data.value" class="input"/></div>
              </div>
              <div class="text-xs text-ink-500">Branches to "yes" or "no" edge based on this check at runtime.</div>
            </template>

            <template v-else-if="selectedNode.kind === 'ab_split'">
              <div><label class="label">Variant A %</label>
                <input v-model.number="selectedNode.data.split_a" type="number" min="0" max="100" class="input"/>
              </div>
              <div class="text-xs text-ink-500">Variant B receives {{ 100 - (selectedNode.data.split_a || 50) }}%.</div>
            </template>

            <template v-else-if="selectedNode.type === 'exit'">
              <div class="text-sm text-ink-500">Customers exit the journey at this node.</div>
            </template>

            <div class="pt-3 border-t border-ink-100">
              <label class="label">Node label</label>
              <input v-model="selectedNode.data.label" class="input" placeholder="Optional label"/>
            </div>
          </div>
        </aside>
      </div>
    </div>

    <Modal v-model="openPicker" title="Start from a template" subtitle="Pick a pre-built journey or start from scratch." size="xl">
      <div class="grid md:grid-cols-2 gap-3">
        <button @click="startBlank" class="card p-4 text-left hover:shadow-md hover:border-brand-500 transition border border-ink-100">
          <div class="w-10 h-10 rounded-lg bg-ink-100 text-ink-700 flex items-center justify-center mb-3"><Icon name="plus"/></div>
          <div class="font-semibold text-ink-900">Blank journey</div>
          <div class="text-xs text-ink-500 mt-1">Start from scratch.</div>
        </button>
        <button v-for="t in templatesList" :key="t.id" @click="useTemplate(t)" class="card p-4 text-left hover:shadow-md hover:border-brand-500 transition border border-ink-100">
          <div class="flex items-center justify-between mb-3">
            <div class="w-10 h-10 rounded-lg bg-brand-100/40 text-brand-500 flex items-center justify-center"><Icon :name="t.icon || 'route'"/></div>
            <span class="chip bg-ink-100 text-ink-700 capitalize">{{ t.category }}</span>
          </div>
          <div class="font-semibold text-ink-900">{{ t.name }}</div>
          <div class="text-xs text-ink-500 mt-1">{{ t.description }}</div>
        </button>
      </div>
    </Modal>

    <Modal v-model="goalOpen" title="Journey goal & controls" subtitle="Define conversion tracking, holdout groups and branching strategy.">
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Goal event</label>
            <select v-model="form.goal.event" class="input">
              <option value="">— none —</option>
              <option v-for="d in eventDefs" :key="d.id" :value="d.name">{{ d.name }}</option>
            </select>
          </div>
          <div><label class="label">Window (days)</label>
            <input v-model.number="form.goal.window_days" type="number" min="1" class="input"/>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Holdout %</label>
            <input v-model.number="form.holdout_percent" type="number" min="0" max="50" class="input"/>
            <div class="text-[11px] text-ink-500 mt-1">Portion excluded from the journey, measured for lift.</div>
          </div>
          <div>
            <label class="label">Branching strategy</label>
            <select v-model="form.variant_strategy" class="input">
              <option value="random">Random A/B split</option>
              <option value="multivariate">Multivariate</option>
              <option value="bandit">Multi-armed bandit</option>
            </select>
            <div class="text-[11px] text-ink-500 mt-1">How A/B split nodes allocate traffic.</div>
          </div>
        </div>
        <div>
          <label class="label">Success goal description</label>
          <input v-model="form.success_goal" class="input" placeholder="e.g. Drive 500 wallet top-ups within 7 days"/>
        </div>
        <div class="card !shadow-none p-3 bg-ink-50 border border-ink-100 text-xs text-ink-700">
          Conversions so far: <span class="font-semibold text-ink-900">{{ editing?.conversion_count || 0 }}</span>
        </div>
      </div>
      <template #footer>
        <button @click="goalOpen = false" class="btn-primary">Done</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const role = useRole()
const requestingApproval = ref(false)
async function askJourneyApproval() {
  if (!editing.value?.id) {
    await saveDraft()
    if (!editing.value?.id) return
  }
  requestingApproval.value = true
  try {
    await role.requestApproval('journey', editing.value.id, form.name || 'Untitled journey', 'Activation approval requested')
    await supabase.from('journeys').update({ requires_approval: true, approval_status: 'pending' }).eq('id', editing.value.id)
    useToast().success('Approval requested', 'A user with permission to activate journeys will review it.')
  } finally { requestingApproval.value = false }
}

const journeys = ref<any[]>([])
const eventDefs = ref<any[]>([])
const templatesList = ref<any[]>([])
const msgTemplates = ref<any[]>([])
const segments = ref<any[]>([])
const lists = ref<any[]>([])
const openPicker = ref(false)
const goalOpen = ref(false)
const editing = ref<any>(null)
const selectedId = ref('')
const lastSavedAt = ref<string>('')
const zoom = ref(1)
const showStats = ref(true)
const nodeStatsMap = ref<Record<string, any>>({})
const abStatsMap = ref<Record<string, any>>({})
function dropFor(nodeId: string) {
  const s = nodeStatsMap.value[nodeId]
  if (!s || !s.entered_count) return 0
  return Math.max(0, Math.round(((s.entered_count - s.completed_count) / s.entered_count) * 100))
}
function abConvPct(nodeId: string, variant: 'a' | 'b') {
  const s = abStatsMap.value[nodeId]
  if (!s) return 0
  const entered = Number(s[variant]) || 0
  const conv = Number(s[variant + '_conv']) || 0
  return entered ? Math.round((conv / entered) * 100) : 0
}
async function loadNodeStats(journeyId: string) {
  nodeStatsMap.value = {}
  abStatsMap.value = {}
  const [ns, vs] = await Promise.all([
    supabase.from('journey_node_stats').select('*').eq('journey_id', journeyId),
    supabase.from('journey_variant_stats').select('*').eq('journey_id', journeyId),
  ])
  const map: Record<string, any> = {}
  ;(ns.data || []).forEach((r: any) => { map[r.node_id] = r })
  nodeStatsMap.value = map
  const ab: Record<string, any> = {}
  ;(vs.data || []).forEach((r: any) => {
    ab[r.node_id] = ab[r.node_id] || {}
    ab[r.node_id][r.variant] = r.entered_count
    ab[r.node_id][r.variant + '_conv'] = r.converted_count
  })
  abStatsMap.value = ab
}
const form = reactive({
  name: '', description: '', status: 'draft', trigger_event: '',
  nodes: [] as any[], edges: [] as any[], goal: { event: '', window_days: 7 } as any,
  steps: [] as any[],
  holdout_percent: 0, variant_strategy: 'random', success_goal: '',
})

const blockGroups = reactive([
  { label: 'Trigger', type: 'trigger', open: true, blocks: [
    { kind: 'activity', label: 'Activity', icon: 'activity' },
    { kind: 'segment', label: 'Segment', icon: 'segment' },
    { kind: 'list', label: 'List', icon: 'list' },
  ]},
  { label: 'Actions', type: 'action', open: true, blocks: [
    { kind: 'email', label: 'Send email', icon: 'mail' },
    { kind: 'push', label: 'Send push', icon: 'bell' },
    { kind: 'sms', label: 'Send SMS', icon: 'smartphone' },
    { kind: 'whatsapp', label: 'WhatsApp', icon: 'smartphone' },
  ]},
  { label: 'Conditions', type: 'condition', open: true, blocks: [
    { kind: 'attribute', label: 'Attribute check', icon: 'filter' },
    { kind: 'event_done', label: 'Did event?', icon: 'activity' },
    { kind: 'condition', label: 'If/else branch', icon: 'layers' },
  ]},
  { label: 'Data', type: 'action', open: true, blocks: [
    { kind: 'update_attribute', label: 'Update attribute', icon: 'edit' },
  ]},
  { label: 'Flow control', type: 'flow', open: true, blocks: [
    { kind: 'wait', label: 'Wait', icon: 'clock' },
    { kind: 'wait_until_event', label: 'Wait until event', icon: 'clock' },
    { kind: 'ab_split', label: 'A/B split', icon: 'layers' },
    { kind: 'exit', label: 'Exit', icon: 'check' },
  ]},
])

const selectedNode = computed(() => form.nodes.find((n: any) => n.id === selectedId.value))

function genId() { return Math.random().toString(36).slice(2, 10) }

function nodeTitle(n: any) {
  if (n.data?.label) return n.data.label
  const titles: Record<string, string> = {
    activity: 'Activity trigger', segment: 'Segment trigger', list: 'List trigger',
    email: 'Send email', push: 'Send push', sms: 'Send SMS', whatsapp: 'WhatsApp',
    wait: 'Wait', wait_until_event: 'Wait until event', ab_split: 'A/B split', exit: 'Exit',
    attribute: 'Attribute check', event_done: 'Event check', condition: 'If/else branch',
    update_attribute: 'Update attribute',
  }
  return titles[n.kind] || n.kind
}
function nodeSubtitle(n: any) {
  if (n.kind === 'activity') return n.data.event ? `on "${n.data.event}"` : 'configure event'
  if (n.kind === 'wait') return `${n.data.value || 1} ${n.data.unit || 'hours'}`
  if (n.kind === 'email') return n.data.subject || 'configure subject'
  if (['push','sms','whatsapp'].includes(n.kind)) return (n.data.body || '').slice(0, 40) || 'configure message'
  if (n.kind === 'ab_split') return `${n.data.split_a || 50}% / ${100 - (n.data.split_a || 50)}%`
  if (n.kind === 'attribute') return `${n.data.field || 'field'} ${n.data.op || 'eq'} ${n.data.value || '—'}`
  if (n.kind === 'event_done') return n.data.event || 'pick event'
  if (n.kind === 'condition') return `${n.data.field || 'field'} ${n.data.op || 'eq'} ${n.data.value || '—'}`
  if (n.kind === 'update_attribute') return `${n.data.op || 'set'} ${n.data.attr_key || 'attr'} = ${n.data.value || ''}`
  if (n.kind === 'wait_until_event') return `until ${n.data.event || 'event'} (max ${n.data.max_value || 1}${(n.data.max_unit || 'h')[0]})`
  if (n.kind === 'segment') return segments.value.find((s: any) => s.id === n.data.segment_id)?.name || 'pick segment'
  if (n.kind === 'list') return lists.value.find((l: any) => l.id === n.data.list_id)?.name || 'pick list'
  return 'exit'
}
function nodeIcon(n: any) {
  const m: Record<string, string> = {
    activity: 'activity', segment: 'segment', list: 'list',
    email: 'mail', push: 'bell', sms: 'smartphone', whatsapp: 'smartphone',
    wait: 'clock', wait_until_event: 'clock', ab_split: 'layers', exit: 'check',
    attribute: 'filter', event_done: 'activity', condition: 'layers', update_attribute: 'edit',
  }
  return m[n.kind] || 'box'
}
function blockColor(type: string) {
  if (type === 'trigger') return 'bg-brand-500 text-white'
  if (type === 'action') return 'bg-accent-500 text-white'
  if (type === 'condition') return 'bg-yellow-500 text-white'
  if (type === 'flow') return 'bg-brand-700 text-white'
  return 'bg-ink-300 text-white'
}
function nodeHeaderBg(n: any) {
  if (n.type === 'trigger') return 'bg-brand-500 text-white'
  if (n.type === 'action') return 'bg-accent-500 text-white'
  if (n.type === 'condition') return 'bg-yellow-500 text-white'
  if (n.type === 'flow') return 'bg-brand-700 text-white'
  if (n.type === 'exit') return 'bg-ink-700 text-white'
  return 'bg-white text-ink-900'
}
function nodeBorder(n: any) {
  if (n.type === 'trigger') return 'border-brand-500'
  if (n.type === 'action') return 'border-accent-500'
  if (n.type === 'condition') return 'border-yellow-500'
  if (n.type === 'flow') return 'border-brand-700'
  if (n.type === 'exit') return 'border-ink-700'
  return 'border-ink-100'
}
function nodeIconColor(n: any) {
  if (n.type === 'trigger') return 'text-brand-500'
  if (n.type === 'action') return 'text-accent-500'
  if (n.type === 'condition') return 'text-yellow-600'
  if (n.type === 'flow') return 'text-brand-700'
  return 'text-ink-700'
}

function activeCount(j: any) { return Math.max(0, (j.entered_count || 0) - (j.completed_count || 0)) }
const channelTemplates = (ch: string) => msgTemplates.value.filter(t => t.channel === ch)
function applyTemplate(n: any) {
  const tpl = msgTemplates.value.find(t => t.id === n.data.template_id)
  if (tpl) { n.data.subject = tpl.subject || tpl.name; n.data.body = tpl.content }
}
function onTriggerChange() {
  const trig = form.nodes.find((n: any) => n.type === 'trigger')
  if (trig?.data.event) form.trigger_event = trig.data.event
}

const dragPayload = ref<{ type: string; kind: string; icon: string; label: string } | null>(null)
function onDragStart(ev: DragEvent, type: string, block: any) {
  dragPayload.value = { type, kind: block.kind, icon: block.icon, label: block.label }
  ev.dataTransfer!.effectAllowed = 'copy'
}
function defaultData(_type: string, kind: string) {
  if (kind === 'wait') return { value: 1, unit: 'hours' }
  if (kind === 'ab_split') return { split_a: 50 }
  if (kind === 'activity') return { event: '' }
  if (kind === 'attribute') return { field: 'country', op: 'eq', value: '' }
  if (kind === 'event_done') return { event: '' }
  if (['email','push','sms','whatsapp'].includes(kind)) return { subject: '', body: '', template_id: '' }
  return {}
}
function onCanvasDrop(ev: DragEvent) {
  if (!dragPayload.value) return
  const world = worldRef.value!
  const rect = world.getBoundingClientRect()
  const x = (ev.clientX - rect.left) / zoom.value
  const y = (ev.clientY - rect.top) / zoom.value
  const p = dragPayload.value
  const type = p.kind === 'exit' ? 'exit' : p.type
  const node: any = {
    id: genId(), type, kind: p.kind,
    x: Math.max(0, x - 100), y: Math.max(0, y - 30),
    data: { ...defaultData(p.type, p.kind), label: '' },
  }
  form.nodes.push(node)
  selectedId.value = node.id
  dragPayload.value = null
}

const dragging = ref<{ node: any; offsetX: number; offsetY: number } | null>(null)
function startDragNode(node: any, ev: MouseEvent) {
  selectedId.value = node.id
  const world = worldRef.value!
  const rect = world.getBoundingClientRect()
  dragging.value = {
    node,
    offsetX: (ev.clientX - rect.left) / zoom.value - node.x,
    offsetY: (ev.clientY - rect.top) / zoom.value - node.y,
  }
  window.addEventListener('mousemove', onNodeDragMove)
  window.addEventListener('mouseup', endNodeDrag)
}
function onNodeDragMove(ev: MouseEvent) {
  if (!dragging.value || !worldRef.value) return
  const rect = worldRef.value.getBoundingClientRect()
  dragging.value.node.x = Math.max(0, (ev.clientX - rect.left) / zoom.value - dragging.value.offsetX)
  dragging.value.node.y = Math.max(0, (ev.clientY - rect.top) / zoom.value - dragging.value.offsetY)
}
function endNodeDrag() {
  dragging.value = null
  window.removeEventListener('mousemove', onNodeDragMove)
  window.removeEventListener('mouseup', endNodeDrag)
}

const connectingFrom = ref<any>(null)
const connectMouse = ref<{ x: number; y: number } | null>(null)
function startConnect(node: any, ev: MouseEvent) {
  connectingFrom.value = node
  const rect = worldRef.value!.getBoundingClientRect()
  connectMouse.value = { x: (ev.clientX - rect.left) / zoom.value, y: (ev.clientY - rect.top) / zoom.value }
  window.addEventListener('mousemove', onConnectMove)
  window.addEventListener('mouseup', cancelConnect)
}
function onConnectMove(ev: MouseEvent) {
  if (!connectingFrom.value || !worldRef.value) return
  const rect = worldRef.value.getBoundingClientRect()
  connectMouse.value = { x: (ev.clientX - rect.left) / zoom.value, y: (ev.clientY - rect.top) / zoom.value }
}
function completeConnect(target: any) {
  if (!connectingFrom.value || connectingFrom.value.id === target.id) return cancelConnect()
  const exists = form.edges.find((e: any) => e.from === connectingFrom.value.id && e.to === target.id)
  if (!exists) form.edges.push({ from: connectingFrom.value.id, to: target.id })
  cancelConnect()
}
function cancelConnect() {
  connectingFrom.value = null
  connectMouse.value = null
  window.removeEventListener('mousemove', onConnectMove)
  window.removeEventListener('mouseup', cancelConnect)
}

const edgePaths = computed(() => {
  return form.edges.map((e: any) => {
    const a = form.nodes.find((n: any) => n.id === e.from)
    const b = form.nodes.find((n: any) => n.id === e.to)
    if (!a || !b) return ''
    const x1 = a.x + 208, y1 = a.y + 40
    const x2 = b.x, y2 = b.y + 40
    const mx = (x1 + x2) / 2
    return `M ${x1} ${y1} C ${mx} ${y1}, ${mx} ${y2}, ${x2} ${y2}`
  })
})
const previewPath = computed(() => {
  if (!connectingFrom.value || !connectMouse.value) return ''
  const a = connectingFrom.value
  const x1 = a.x + 208, y1 = a.y + 40
  const x2 = connectMouse.value.x, y2 = connectMouse.value.y
  const mx = (x1 + x2) / 2
  return `M ${x1} ${y1} C ${mx} ${y1}, ${mx} ${y2}, ${x2} ${y2}`
})

function removeNode(n: any) {
  form.nodes = form.nodes.filter((x: any) => x.id !== n.id)
  form.edges = form.edges.filter((e: any) => e.from !== n.id && e.to !== n.id)
  if (selectedId.value === n.id) selectedId.value = ''
}

const canvasRef = ref<HTMLElement | null>(null)
const worldRef = ref<HTMLElement | null>(null)
const panning = ref(false)
const panStart = ref<{ x: number; y: number; sx: number; sy: number } | null>(null)
function startPan(ev: MouseEvent) {
  if ((ev.target as HTMLElement).closest('[draggable]') || (ev.target as HTMLElement).closest('.cursor-move')) return
  if (ev.button !== 0) return
  panning.value = true
  panStart.value = { x: ev.clientX, y: ev.clientY, sx: canvasRef.value!.scrollLeft, sy: canvasRef.value!.scrollTop }
}
function onPan(ev: MouseEvent) {
  if (!panning.value || !panStart.value || !canvasRef.value) return
  canvasRef.value.scrollLeft = panStart.value.sx - (ev.clientX - panStart.value.x)
  canvasRef.value.scrollTop = panStart.value.sy - (ev.clientY - panStart.value.y)
}
function stopPan() { panning.value = false; panStart.value = null }

function fitToScreen() {
  if (!form.nodes.length) { zoom.value = 1; canvasRef.value?.scrollTo({ top: 0, left: 0 }); return }
  zoom.value = 1
  const first = form.nodes[0]
  canvasRef.value?.scrollTo({ left: Math.max(0, first.x - 100), top: Math.max(0, first.y - 100) })
}

async function load() {
  if (!workspaceId.value) return
  const [j, e, jt, tt, sg, ls] = await Promise.all([
    supabase.from('journeys').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('event_definitions').select('id,name').eq('workspace_id', workspaceId.value),
    supabase.from('journey_templates').select('*').or(`is_system.eq.true,workspace_id.eq.${workspaceId.value}`).order('is_system', { ascending: false }),
    supabase.from('templates').select('id,name,channel,subject,content').eq('workspace_id', workspaceId.value),
    supabase.from('segments').select('id,name').eq('workspace_id', workspaceId.value),
    supabase.from('lists').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  journeys.value = j.data || []
  eventDefs.value = e.data || []
  templatesList.value = jt.data || []
  msgTemplates.value = tt.data || []
  segments.value = sg.data || []
  lists.value = ls.data || []
}

function resetForm() {
  form.name = 'Untitled journey'
  form.description = ''
  form.status = 'draft'
  form.trigger_event = ''
  form.nodes = []
  form.edges = []
  form.goal = { event: '', window_days: 7 }
  form.steps = []
  form.holdout_percent = 0
  form.variant_strategy = 'random'
  form.success_goal = ''
  selectedId.value = ''
  lastSavedAt.value = ''
}
function startBlank() {
  openPicker.value = false
  resetForm()
  editing.value = {}
}
function useTemplate(t: any) {
  openPicker.value = false
  resetForm()
  form.name = t.name
  form.description = t.description
  form.trigger_event = t.trigger_event
  const startX = 100, startY = 120, stepX = 280
  const trig: any = { id: genId(), type: 'trigger', kind: 'activity', x: startX, y: startY, data: { event: t.trigger_event || '', label: '' } }
  form.nodes.push(trig)
  let prev: any = trig
  const steps = t.steps || []
  steps.forEach((s: any, i: number) => {
    const type = s.type === 'condition' ? 'condition' : (s.type === 'wait' ? 'flow' : 'action')
    const kind = s.type === 'wait' ? 'wait' : (s.type === 'condition' ? 'attribute' : s.type)
    const data: any = s.type === 'wait' ? { value: s.hours || 1, unit: 'hours', label: '' } : { ...s, label: '' }
    const node: any = { id: genId(), type, kind, x: startX + (i + 1) * stepX, y: startY, data }
    form.nodes.push(node)
    form.edges.push({ from: prev.id, to: node.id })
    prev = node
  })
  const exit: any = { id: genId(), type: 'exit', kind: 'exit', x: startX + (steps.length + 1) * stepX, y: startY, data: { label: '' } }
  form.nodes.push(exit)
  form.edges.push({ from: prev.id, to: exit.id })
  editing.value = {}
}
async function openJourney(j: any) {
  resetForm()
  editing.value = j
  form.name = j.name
  form.description = j.description || ''
  form.status = j.status
  form.trigger_event = j.trigger_event || ''
  form.nodes = Array.isArray(j.nodes) && j.nodes.length ? JSON.parse(JSON.stringify(j.nodes)) : []
  form.edges = Array.isArray(j.edges) ? JSON.parse(JSON.stringify(j.edges)) : []
  form.goal = j.goal || { event: '', window_days: 7 }
  form.holdout_percent = j.holdout_percent || 0
  form.variant_strategy = j.variant_strategy || 'random'
  form.success_goal = j.success_goal || ''
  if (j.id) await loadNodeStats(j.id)
}
function closeEditor() { editing.value = null; load() }

async function saveDraft() { await persist('draft') }
async function publish() {
  if (!form.nodes.some((n: any) => n.type === 'trigger')) { useToast().warning('Trigger required', 'Add a trigger block to publish this journey.'); return }
  await persist('active')
}

async function persist(status: string) {
  const steps: any[] = form.nodes
    .filter((n: any) => n.type !== 'trigger' && n.type !== 'exit')
    .map((n: any) => ({ type: n.kind, ...n.data }))
  const payload: any = {
    workspace_id: workspaceId.value,
    name: form.name,
    description: form.description,
    status,
    trigger_event: form.trigger_event,
    nodes: form.nodes,
    edges: form.edges,
    goal: form.goal,
    steps,
    holdout_percent: form.holdout_percent || 0,
    variant_strategy: form.variant_strategy || 'random',
    success_goal: form.success_goal || '',
  }
  if (editing.value?.id) {
    const { data, error } = await supabase.from('journeys').update(payload).eq('id', editing.value.id).select().maybeSingle()
    if (error) { useToast().error('Could not save', error.message); return }
    if (data) editing.value = data
  } else {
    const { data, error } = await supabase.from('journeys').insert({ ...payload, entered_count: 0, completed_count: 0 }).select().maybeSingle()
    if (error) { useToast().error('Could not save', error.message); return }
    if (data) editing.value = data
  }
  form.status = status
  lastSavedAt.value = new Date().toISOString()
}

watch(workspaceId, load, { immediate: true })
</script>
