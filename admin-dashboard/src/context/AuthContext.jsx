import { createContext, useContext, useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { fetchApi, setAuth, clearAuth, getToken, getEmail } from '../api/client'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [token, setToken] = useState(getToken)
  const [email, setEmail] = useState(getEmail)
  const [mfaRequired, setMfaRequired] = useState(false)
  const [mfaSessionToken, setMfaSessionToken] = useState(null)
  const [mfaType, setMfaType] = useState(null)
  const [mfaSetupRequired, setMfaSetupRequired] = useState(false)
  const navigate = useNavigate()

  const login = useCallback(async (emailInput) => {
    const data = await fetchApi('/consumer/login', {
      method: 'POST',
      body: JSON.stringify({ email: emailInput }),
    })

    // MFA setup required (admin first login)
    if (data.mfa_setup_required) {
      setAuth(data.tempToken, emailInput)
      setToken(data.tempToken)
      setEmail(emailInput)
      setMfaSetupRequired(true)
      navigate('/mfa-setup')
      return
    }

    // MFA verification required
    if (data.mfa_required) {
      setEmail(emailInput)
      setMfaRequired(true)
      setMfaSessionToken(data.mfa_session_token)
      setMfaType(data.mfa_type)
      navigate('/mfa-verify')
      return
    }

    // Normal login (no MFA)
    const jwt = data.singleUseToken || data.token
    setAuth(jwt, emailInput)
    setToken(jwt)
    setEmail(emailInput)
    navigate('/dashboard')
  }, [navigate])

  const verifyMfa = useCallback(async (code) => {
    const data = await fetchApi('/consumer/verify-mfa', {
      method: 'POST',
      body: JSON.stringify({ mfa_session_token: mfaSessionToken, code }),
    })
    const jwt = data.singleUseToken
    setAuth(jwt, email)
    setToken(jwt)
    setMfaRequired(false)
    setMfaSessionToken(null)
    setMfaType(null)
    navigate('/dashboard')
  }, [mfaSessionToken, email, navigate])

  const setupMfa = useCallback(async () => {
    const data = await fetchApi('/consumer/setup-mfa', { method: 'POST' })
    return data
  }, [])

  const confirmMfaSetup = useCallback(async (code) => {
    await fetchApi('/consumer/confirm-mfa-setup', {
      method: 'POST',
      body: JSON.stringify({ code }),
    })
    setMfaSetupRequired(false)
    navigate('/dashboard')
  }, [navigate])

  const logout = useCallback(async () => {
    try {
      await fetchApi('/consumer/logout', { method: 'POST' })
    } catch {
      // ignore errors during logout
    }
    clearAuth()
    setToken(null)
    setEmail(null)
    setMfaRequired(false)
    setMfaSessionToken(null)
    setMfaType(null)
    setMfaSetupRequired(false)
    navigate('/login')
  }, [navigate])

  const value = {
    token, email, login, logout, isAuthenticated: !!token,
    mfaRequired, mfaSessionToken, mfaType, mfaSetupRequired,
    verifyMfa, setupMfa, confirmMfaSetup,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
