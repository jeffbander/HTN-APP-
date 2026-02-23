import { createContext, useContext, useState, useCallback, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  fetchApi, setDashboardAuth, clearAuth, getToken, getEmail, getRole, getUserName,
  setOnAuthExpired,
} from '../api/client'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [token, setToken] = useState(getToken)
  const [email, setEmail] = useState(getEmail)
  const [role, setRole] = useState(getRole)
  const [userName, setUserName] = useState(getUserName)
  const [mfaRequired, setMfaRequired] = useState(false)
  const [mfaSessionToken, setMfaSessionToken] = useState(null)
  const [mfaType, setMfaType] = useState(null)
  const [mfaSetupRequired, setMfaSetupRequired] = useState(false)
  const navigate = useNavigate()

  const login = useCallback(async (emailInput) => {
    const data = await fetchApi('/dashboard/login', {
      method: 'POST',
      body: JSON.stringify({ email: emailInput }),
    })

    const jwt = data.singleUseToken || data.token
    setDashboardAuth(jwt, emailInput, { role: data.role, name: data.name })
    setToken(jwt)
    setEmail(emailInput)
    setRole(data.role)
    setUserName(data.name)
    navigate('/dashboard')
  }, [navigate])

  const verifyMfa = useCallback(async (code) => {
    const data = await fetchApi('/dashboard/verify-mfa', {
      method: 'POST',
      body: JSON.stringify({ mfa_session_token: mfaSessionToken, code }),
    })
    const jwt = data.singleUseToken
    setDashboardAuth(jwt, email, { role: data.role, name: data.name })
    setToken(jwt)
    setRole(data.role)
    setUserName(data.name)
    setMfaRequired(false)
    setMfaSessionToken(null)
    setMfaType(null)
    navigate('/dashboard')
  }, [mfaSessionToken, email, navigate])

  const setupMfa = useCallback(async () => {
    const data = await fetchApi('/dashboard/setup-mfa', { method: 'POST' })
    return data
  }, [])

  const confirmMfaSetup = useCallback(async (code) => {
    const data = await fetchApi('/dashboard/confirm-mfa-setup', {
      method: 'POST',
      body: JSON.stringify({ code }),
    })
    // Return data (includes backup_codes) — caller shows them before navigating
    return data
  }, [])

  const finishMfaSetup = useCallback(() => {
    setMfaSetupRequired(false)
    clearAuth()
    setToken(null)
    setEmail(null)
    setRole(null)
    setUserName(null)
    navigate('/login')
  }, [navigate])

  const logout = useCallback(async () => {
    try {
      await fetchApi('/dashboard/logout', { method: 'POST' })
    } catch {
      // ignore errors during logout
    }
    clearAuth()
    setToken(null)
    setEmail(null)
    setRole(null)
    setUserName(null)
    setMfaRequired(false)
    setMfaSessionToken(null)
    setMfaType(null)
    setMfaSetupRequired(false)
    navigate('/login')
  }, [navigate])

  // Register 401 handler so fetchApi can reset React state without hard redirect
  useEffect(() => {
    setOnAuthExpired(() => {
      setToken(null)
      setEmail(null)
      setRole(null)
      setUserName(null)
      setMfaRequired(false)
      setMfaSessionToken(null)
      setMfaType(null)
      setMfaSetupRequired(false)
      navigate('/login')
    })
  }, [navigate])

  const hasRole = useCallback((...roles) => roles.includes(role), [role])

  // Reset all auth state without navigating (used by Login page)
  const resetAuth = useCallback(() => {
    clearAuth()
    setToken(null)
    setEmail(null)
    setRole(null)
    setUserName(null)
    setMfaRequired(false)
    setMfaSessionToken(null)
    setMfaType(null)
    setMfaSetupRequired(false)
  }, [])

  const value = {
    token, email, role, userName, login, logout, hasRole, resetAuth,
    isAuthenticated: !!token,
    mfaRequired, mfaSessionToken, mfaType, mfaSetupRequired,
    verifyMfa, setupMfa, confirmMfaSetup, finishMfaSetup,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
