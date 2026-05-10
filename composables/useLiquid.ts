export function renderLiquid(template: string, context: Record<string, any> = {}) {
  if (!template) return ''
  let out = template

  out = out.replace(/\{%\s*if\s+([\w.]+)\s*%\}([\s\S]*?)(?:\{%\s*else\s*%\}([\s\S]*?))?\{%\s*endif\s*%\}/g,
    (_m, path, a, b) => {
      const v = resolve(path, context)
      return v ? a : (b || '')
    })

  out = out.replace(/\{\{\s*([\w.]+)\s*(?:\|\s*default:\s*["']([^"']*)["'])?\s*\}\}/g,
    (_m, path, dflt) => {
      const v = resolve(path, context)
      if (v === undefined || v === null || v === '') return dflt || ''
      if (typeof v === 'object') return JSON.stringify(v)
      return String(v)
    })

  return out
}

function resolve(path: string, ctx: Record<string, any>): any {
  return path.split('.').reduce((acc: any, k: string) => (acc == null ? acc : acc[k]), ctx)
}

export function sampleContext(customer?: any) {
  const base = {
    first_name: 'Ada', last_name: 'Okafor', email: 'ada.okafor@sycamore.ng',
    phone: '+2348031234567', city: 'Lagos', country: 'NG',
    amount: '25,000', beneficiary: 'GTBank ***4921', reference: 'REF-A1B2C3D4',
    attributes: { kyc_tier: 3, wallet_balance_ngn: 1_250_000, is_premium: true, bvn_verified: true },
    workspace: { name: 'Sycamore' },
  }
  if (!customer) return base
  return {
    ...base,
    first_name: customer.first_name || base.first_name,
    last_name: customer.last_name || base.last_name,
    email: customer.email || base.email,
    phone: customer.phone || base.phone,
    city: customer.city || base.city,
    country: customer.country || base.country,
    attributes: customer.attributes || base.attributes,
  }
}
