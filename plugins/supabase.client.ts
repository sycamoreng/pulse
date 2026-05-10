import { createClient } from '@supabase/supabase-js'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()
  const network = useNetwork()
  const trackingFetch: typeof fetch = (input, init) => {
    network.begin()
    return fetch(input, init).finally(() => network.end())
  }
  const supabase = createClient(
    config.public.supabaseUrl as string,
    config.public.supabaseAnonKey as string,
    {
      auth: { persistSession: true, autoRefreshToken: true },
      global: { fetch: trackingFetch },
    }
  )
  return { provide: { supabase } }
})
