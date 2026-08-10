import { useEffect, useState } from 'react'
import { supabase } from '../src/lib/supabaseClient'

export default function Home() {
  const [session, setSession] = useState(null)

  useEffect(() => {
    const s = supabase.auth.getSession().then(r => setSession(r.data.session))
  }, [])

  return (
    <main style={{padding:40}}>
      <h1>Sales Report Prototype</h1>
      {session ? (
        <div>
          <p>Signed in as {session.user.email}</p>
          <button onClick={() => supabase.auth.signOut()}>Sign out</button>
        </div>
      ) : (
        <div>
          <button onClick={() => supabase.auth.signInWithOAuth({ provider: 'google' })}>Sign in with Google</button>
        </div>
      )}
    </main>
  )
}
