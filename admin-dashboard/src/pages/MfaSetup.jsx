import { useState, useEffect, useRef } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import styles from './Login.module.css'

export default function MfaSetup() {
  const { setupMfa, confirmMfaSetup, mfaSetupRequired, isAuthenticated } = useAuth()
  const [step, setStep] = useState(1) // 1=QR, 2=verify, 3=backup codes
  const [setupData, setSetupData] = useState(null)
  const [code, setCode] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const canvasRef = useRef(null)

  if (!isAuthenticated && !mfaSetupRequired) return <Navigate to="/login" replace />
  if (!mfaSetupRequired) return <Navigate to="/dashboard" replace />

  useEffect(() => {
    const initSetup = async () => {
      setLoading(true)
      try {
        const data = await setupMfa()
        setSetupData(data)
      } catch (err) {
        setError(err.message || 'Failed to initialize MFA setup')
      } finally {
        setLoading(false)
      }
    }
    initSetup()
  }, [setupMfa])

  useEffect(() => {
    if (setupData?.provisioning_uri && canvasRef.current) {
      import('qrcode').then((QRCode) => {
        QRCode.toCanvas(canvasRef.current, setupData.provisioning_uri, {
          width: 200,
          margin: 2,
        })
      }).catch(() => {
        // QR library not available, user can use manual secret
      })
    }
  }, [setupData])

  const handleVerify = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await confirmMfaSetup(code)
      setStep(3)
    } catch (err) {
      setError(err.message || 'Invalid code')
      setLoading(false)
    }
  }

  if (loading && !setupData) {
    return (
      <div className={styles.container}>
        <div className={styles.card}>
          <h1 className={styles.title}>Setting up MFA...</h1>
        </div>
      </div>
    )
  }

  return (
    <div className={styles.container}>
      <div className={styles.card} style={{ maxWidth: 480 }}>
        <div className={styles.logo}>
          <svg viewBox="0 0 24 24" width="36" height="36">
            <path fill="white" d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z" />
          </svg>
        </div>
        <h1 className={styles.title}>Set Up MFA</h1>

        {error && <div className={styles.error}>{error}</div>}

        {step === 1 && setupData && (
          <>
            <p className={styles.subtitle}>
              Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)
            </p>
            <div style={{ display: 'flex', justifyContent: 'center', margin: '20px 0' }}>
              <canvas ref={canvasRef} />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.label}>Or enter this secret manually:</label>
              <input
                className={styles.input}
                type="text"
                value={setupData.secret}
                readOnly
                onClick={(e) => e.target.select()}
                style={{ fontFamily: 'monospace', textAlign: 'center', letterSpacing: '2px' }}
              />
            </div>
            <button
              className={styles.loginBtn}
              type="button"
              onClick={() => setStep(2)}
            >
              Next
            </button>
          </>
        )}

        {step === 2 && (
          <form onSubmit={handleVerify}>
            <p className={styles.subtitle}>
              Enter the 6-digit code from your authenticator app to confirm setup
            </p>
            <div className={styles.formGroup}>
              <label className={styles.label}>Verification Code</label>
              <input
                className={styles.input}
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                placeholder="000000"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                required
                autoFocus
              />
            </div>
            <button className={styles.loginBtn} type="submit" disabled={loading}>
              {loading ? 'Verifying...' : 'Verify & Activate'}
            </button>
            <p className={styles.footer} style={{ cursor: 'pointer' }} onClick={() => setStep(1)}>
              Back to QR code
            </p>
          </form>
        )}

        {step === 3 && setupData && (
          <>
            <p className={styles.subtitle}>
              Save these backup codes in a secure location. Each code can only be used once.
            </p>
            <div style={{
              background: '#f5f5f5',
              padding: '16px',
              borderRadius: '8px',
              margin: '16px 0',
              fontFamily: 'monospace',
              fontSize: '14px',
              lineHeight: '2',
              textAlign: 'center',
            }}>
              {setupData.backup_codes.map((c, i) => (
                <div key={i}>{c}</div>
              ))}
            </div>
            <button
              className={styles.loginBtn}
              type="button"
              onClick={() => {
                navigator.clipboard?.writeText(setupData.backup_codes.join('\n'))
              }}
              style={{ marginBottom: '12px' }}
            >
              Copy Codes
            </button>
            <button
              className={styles.loginBtn}
              type="button"
              onClick={() => window.location.href = '/dashboard'}
              style={{ background: '#28a745' }}
            >
              Done
            </button>
          </>
        )}
      </div>
    </div>
  )
}
