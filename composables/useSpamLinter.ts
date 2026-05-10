// Client-side deliverability heuristics. No external calls.
// Each rule returns a severity: 'error' blocks send, 'warn' flags, 'info' notes.

export type LintSeverity = 'error' | 'warn' | 'info'
export interface LintFinding {
  severity: LintSeverity
  code: string
  message: string
}

const SPAMMY_PHRASES = [
  '100% free', 'act now', 'amazing', 'buy now', 'cash bonus', 'click here',
  'congratulations', 'double your', 'earn $', 'earn extra', 'free access',
  'free gift', 'free money', 'get paid', 'guaranteed', 'increase sales',
  'investment', 'limited time', 'lowest price', 'make money', 'no cost',
  'no obligation', 'offer expires', 'order now', 'risk-free', 'satisfaction guaranteed',
  'special promotion', 'urgent', 'winner', 'winning', 'you are a winner',
]

export function useSpamLinter() {
  function lintEmail(opts: { subject?: string; html?: string; text?: string; channel?: string }): LintFinding[] {
    const out: LintFinding[] = []
    const subject = (opts.subject || '').trim()
    const body = (opts.html || opts.text || '').trim()
    const plain = body.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()

    if (opts.channel && opts.channel !== 'email') return out

    if (!subject) {
      out.push({ severity: 'error', code: 'subject_missing', message: 'Subject line is empty.' })
    } else {
      if (subject.length < 10) out.push({ severity: 'warn', code: 'subject_short', message: 'Subject is shorter than 10 characters — inboxes may truncate it awkwardly.' })
      if (subject.length > 70) out.push({ severity: 'warn', code: 'subject_long', message: `Subject is ${subject.length} characters — most inboxes cut off around 60.` })
      const upper = subject.replace(/[^A-Z]/g, '').length
      const letters = subject.replace(/[^A-Za-z]/g, '').length
      if (letters > 0 && upper / letters > 0.5 && letters >= 8) out.push({ severity: 'warn', code: 'subject_shouting', message: 'Subject looks SHOUTY. More than half the letters are uppercase.' })
      const excl = (subject.match(/!/g) || []).length
      if (excl >= 2) out.push({ severity: 'warn', code: 'subject_excl', message: 'Multiple exclamation marks in the subject raise spam scores.' })
    }

    if (!plain) {
      out.push({ severity: 'error', code: 'body_missing', message: 'Message body is empty.' })
    } else {
      if (plain.length < 40) out.push({ severity: 'warn', code: 'body_short', message: 'Body is very short — message may be flagged as low-content.' })
      const upperWords = plain.split(/\s+/).filter(w => w.length >= 4 && w === w.toUpperCase()).length
      if (upperWords >= 3) out.push({ severity: 'warn', code: 'body_shouting', message: `${upperWords} all-caps words in body. Tone it down.` })
      const phraseHits = SPAMMY_PHRASES.filter(p => plain.toLowerCase().includes(p))
      if (phraseHits.length) out.push({ severity: 'warn', code: 'body_spam_words', message: `Contains spam-trigger phrases: ${phraseHits.slice(0, 3).join(', ')}${phraseHits.length > 3 ? '…' : ''}` })

      const imgMatches = (opts.html || '').match(/<img[\s>]/gi) || []
      const textLen = plain.length
      if (opts.html && imgMatches.length && textLen < 80) {
        out.push({ severity: 'warn', code: 'image_heavy', message: 'Image-heavy email with little text. Add more plain-text copy for deliverability.' })
      }

      const hasUnsub = /unsubscribe|opt[- ]?out|manage preferences|\{\{unsubscribe_url\}\}/i.test(opts.html || plain)
      if (!hasUnsub) out.push({ severity: 'error', code: 'no_unsubscribe', message: 'No unsubscribe link found. Required by CAN-SPAM and most ESPs.' })

      const urlCount = (plain.match(/https?:\/\//g) || []).length
      const words = plain.split(/\s+/).length
      if (urlCount > 0 && words > 0 && urlCount / words > 0.08) {
        out.push({ severity: 'warn', code: 'link_heavy', message: 'Link-to-text ratio is high. Spam filters look for this.' })
      }
    }

    return out
  }

  function scoreFromFindings(findings: LintFinding[]): { score: number; label: string; tone: string } {
    const weight = findings.reduce((a, f) => a + (f.severity === 'error' ? 30 : f.severity === 'warn' ? 10 : 2), 0)
    const score = Math.max(0, 100 - weight)
    const label = score >= 85 ? 'Inbox-ready' : score >= 65 ? 'Needs polish' : score >= 40 ? 'Risky' : 'Likely spam'
    const tone = score >= 85 ? 'accent' : score >= 65 ? 'brand' : score >= 40 ? 'amber' : 'red'
    return { score, label, tone }
  }

  return { lintEmail, scoreFromFindings }
}
