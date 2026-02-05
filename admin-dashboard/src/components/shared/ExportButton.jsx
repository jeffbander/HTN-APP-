import { useState } from 'react'
import styles from './ExportButton.module.css'

export default function ExportButton({ onClick, label, disabled, variant }) {
  const [loading, setLoading] = useState(false)

  async function handleClick() {
    if (loading || disabled) return
    setLoading(true)
    try {
      await onClick()
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      className={`${styles.btn} ${variant === 'secondary' ? styles.secondary : ''}`}
      onClick={handleClick}
      disabled={loading || disabled}
    >
      {loading ? (
        <>
          <span className={styles.spinner} />
          Exporting...
        </>
      ) : (
        <>
          <span className={styles.icon}>↓</span>
          {label || 'Export CSV'}
        </>
      )}
    </button>
  )
}
