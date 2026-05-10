<template>
  <div>
    <h1>AMP for Email</h1>
    <p>AMP for Email lets recipients interact with dynamic content — forms, carousels, accordions, live pricing — directly inside their inbox, without clicking through to a browser. Gmail, Yahoo, and Mail.ru support it today.</p>

    <h2>Enabling AMP</h2>
    <ol>
      <li>Open any email template and check <em>Enable AMP for Email</em>.</li>
      <li>Paste your AMP HTML into the new editor that appears.</li>
      <li>Your existing HTML remains as the fallback for non-AMP clients.</li>
    </ol>

    <h2>Sender registration</h2>
    <p>Providers require senders to register before they will render AMP payloads. To qualify you must:</p>
    <ul>
      <li>Authenticate sending domains with SPF, DKIM, and DMARC (Pulse checks this automatically).</li>
      <li>Maintain a low complaint rate (&lt; 0.1%).</li>
      <li>Register with each provider separately (Gmail, Yahoo, Mail.ru).</li>
    </ul>

    <h2>AMP components you can use</h2>
    <ul>
      <li><code>amp-carousel</code> — product galleries.</li>
      <li><code>amp-form</code> + <code>amp-bind</code> — surveys and RSVPs.</li>
      <li><code>amp-list</code> — live data from your backend (must be CORS-configured).</li>
      <li><code>amp-accordion</code> — FAQ or progressive disclosure.</li>
    </ul>

    <h2>Fallback behaviour</h2>
    <p>When a recipient's client doesn't support AMP, Pulse delivers the standard HTML version. You should always keep the HTML body complete and self-contained — never assume AMP will render.</p>

    <h2>Preview</h2>
    <p>Preview AMP in Gmail's AMP Playground (<a href="https://amp.gmail.dev/playground/" target="_blank">amp.gmail.dev</a>). Pulse shows a basic preview, but in-client rendering is the only reliable test.</p>

    <div class="callout callout-warn">
      <div>AMP is a premium capability. It's available on Growth and Business plans.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'AMP for Email · Pulse Docs' })
</script>
