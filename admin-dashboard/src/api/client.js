const TOKEN_KEY = 'htn_admin_token'
const EMAIL_KEY = 'htn_admin_email'
const ROLE_KEY = 'htn_admin_role'
const NAME_KEY = 'htn_admin_name'
const UNION_KEY = 'htn_admin_union_id'

export function getToken() {
  return localStorage.getItem(TOKEN_KEY)
}

export function getEmail() {
  return localStorage.getItem(EMAIL_KEY)
}

export function getRole() {
  return localStorage.getItem(ROLE_KEY)
}

export function getUserName() {
  return localStorage.getItem(NAME_KEY)
}

export function getUnionId() {
  return localStorage.getItem(UNION_KEY)
}

export function setAuth(token, email) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(EMAIL_KEY, email)
}

export function setDashboardAuth(token, email, { role, name, unionId } = {}) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(EMAIL_KEY, email)
  if (role) localStorage.setItem(ROLE_KEY, role)
  if (name) localStorage.setItem(NAME_KEY, name)
  if (unionId) localStorage.setItem(UNION_KEY, String(unionId))
}

export function clearAuth() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(EMAIL_KEY)
  localStorage.removeItem(ROLE_KEY)
  localStorage.removeItem(NAME_KEY)
  localStorage.removeItem(UNION_KEY)
}

// Callback for AuthContext to register — called on 401 to reset React state
let _onAuthExpired = null
export function setOnAuthExpired(cb) {
  _onAuthExpired = cb
}

export async function fetchApi(path, options = {}) {
  const token = getToken()
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  }

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), 30000)

  let res
  try {
    res = await fetch(path, { ...options, headers, signal: controller.signal })
  } catch (err) {
    clearTimeout(timeoutId)
    if (err.name === 'AbortError') {
      throw new Error('Request timed out. Please try again.')
    }
    throw err
  }
  clearTimeout(timeoutId)

  if (res.status === 401) {
    // Only treat as session expiry for dashboard-auth endpoints
    const isDashboardEndpoint = /^\/(dashboard|super-admin|union-leader|shipping|nurse)\//.test(path)
    const isAuthEndpoint = path.includes('/login') || path.includes('/verify-mfa')
    if (isDashboardEndpoint && !isAuthEndpoint) {
      clearAuth()
      if (_onAuthExpired) _onAuthExpired()
    }
    const body = await res.json().catch(() => ({}))
    throw new Error(body.error || 'Session expired')
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.error || `Request failed (${res.status})`)
  }

  return res.json()
}
