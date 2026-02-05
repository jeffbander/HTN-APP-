import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import styles from './Login.module.css'

export default function MfaVerify() {
  const { verifyMfa, mfaRequired, mfaType, isAuthenticated } = useAuth()
  const [code, setCode] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  if (isAuthenticated && !mfaRequired) return <Navigate to="/dashboard" replace />
  if (!mfaRequired) return <Navigate to="/login" replace />

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await verifyMfa(code)
    } catch (err) {
      setError(err.message || 'Verification failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className={styles.container}>
      <form className={styles.card} onSubmit={handleSubmit}>
        <div className={styles.logo}>
          <svg viewBox="0 0 24 24" width="36" height="36">
            <path fill="white" d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM12 17c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zM15.1 8H8.9V6c0-1.71 1.39-3.1 3.1-3.1s3.1 1.39 3.1 3.1v2z" />
          </svg>
        </div>
        <h1 className={styles.title}>Verify Identity</h1>
        <p className={styles.subtitle}>
          {mfaType === 'totp'
            ? 'Enter the code from your authenticator app'
            : 'Enter the 6-digit code sent to your email'}
        </p>
        {error && <div className={styles.error}>{error}</div>}
        <div className={styles.formGroup}>
          <label className={styles.label}>Verification Code</label>
          <input
            className={styles.input}
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={8}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\s/g, ''))}
            required
            autoFocus
          />
        </div>
        <button className={styles.loginBtn} type="submit" disabled={loading}>
          {loading ? 'Verifying...' : 'Verify'}
        </button>
        <p className={styles.footer}>
          {mfaType === 'totp'
            ? 'You can also use a backup code'
            : 'Check your email for the verification code'}
        </p>
      </form>
    </div>
  )
}
