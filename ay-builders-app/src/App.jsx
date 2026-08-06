import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import AuthScreen from './pages/AuthScreen'
import SetupCompany from './pages/SetupCompany'
import Dashboard from './pages/Dashboard'

export default function App() {
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [company, setCompany] = useState(null)
  const [loading, setLoading] = useState(true)

  const loadProfile = async (userId) => {
    const { data: prof, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle()

    if (error) {
      console.error(error)
      setProfile(null)
      setCompany(null)
      return
    }

    setProfile(prof)

    if (prof?.company_id) {
      const { data: comp } = await supabase
        .from('companies')
        .select('*')
        .eq('id', prof.company_id)
        .maybeSingle()
      setCompany(comp)
    } else {
      setCompany(null)
    }
  }

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session: s } }) => {
      setSession(s)
      if (s?.user) loadProfile(s.user.id).finally(() => setLoading(false))
      else setLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s)
      if (s?.user) loadProfile(s.user.id)
      else {
        setProfile(null)
        setCompany(null)
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  const refreshProfile = () => {
    if (session?.user) return loadProfile(session.user.id)
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center text-sm text-[#6B6E72]">
        Loading…
      </div>
    )
  }

  if (!session) {
    return <AuthScreen />
  }

  // Logged in but no company yet → create company (first admin)
  if (!profile?.company_id) {
    return (
      <SetupCompany
        user={session.user}
        profile={profile}
        onDone={refreshProfile}
      />
    )
  }

  return (
    <Dashboard
      session={session}
      profile={profile}
      company={company}
      onCompanyUpdate={refreshProfile}
      onLogout={async () => {
        await supabase.auth.signOut()
    try {
      if (navigator.clearAppBadge) await navigator.clearAppBadge()
    } catch (_) {}
      }}
    />
  )
}
