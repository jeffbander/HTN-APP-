import { useState, useEffect, useRef } from 'react'
import styles from './DateRangeFilter.module.css'

const PRESETS = [
  { label: 'Today', days: 0 },
  { label: 'Last 7 Days', days: 7 },
  { label: 'Last 30 Days', days: 30 },
  { label: 'Last 90 Days', days: 90 },
  { label: 'This Year', days: 'year' },
]

function formatDate(date) {
  if (!date) return ''
  return date.toISOString().split('T')[0]
}

function getPresetDates(preset) {
  const now = new Date()
  const to = new Date(now)
  to.setHours(23, 59, 59, 999)

  let from
  if (preset.days === 'year') {
    from = new Date(now.getFullYear(), 0, 1)
  } else if (preset.days === 0) {
    from = new Date(now)
    from.setHours(0, 0, 0, 0)
  } else {
    from = new Date(now)
    from.setDate(from.getDate() - preset.days)
    from.setHours(0, 0, 0, 0)
  }

  return { from: formatDate(from), to: formatDate(to) }
}

export default function DateRangeFilter({ label, fromDate, toDate, onChange }) {
  const [open, setOpen] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    function handleClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  function handlePreset(preset) {
    const dates = getPresetDates(preset)
    onChange(dates.from, dates.to)
    setOpen(false)
  }

  function handleClear() {
    onChange('', '')
    setOpen(false)
  }

  const hasValue = fromDate || toDate
  const displayText = hasValue
    ? `${fromDate || 'Start'} - ${toDate || 'End'}`
    : label || 'Date Range'

  return (
    <div className={styles.container} ref={ref}>
      <button className={styles.trigger} onClick={() => setOpen(!open)}>
        {displayText}
        {hasValue && (
          <span className={styles.clearBtn} onClick={(e) => { e.stopPropagation(); handleClear() }}>
            ×
          </span>
        )}
        <span className={styles.arrow}>{open ? '\u25B2' : '\u25BC'}</span>
      </button>

      {open && (
        <div className={styles.dropdown}>
          <div className={styles.presets}>
            {PRESETS.map((preset) => (
              <button
                key={preset.label}
                className={styles.presetBtn}
                onClick={() => handlePreset(preset)}
              >
                {preset.label}
              </button>
            ))}
          </div>

          <div className={styles.divider} />

          <div className={styles.customRange}>
            <div className={styles.inputGroup}>
              <label>From</label>
              <input
                type="date"
                value={fromDate || ''}
                onChange={(e) => onChange(e.target.value, toDate)}
                className={styles.dateInput}
              />
            </div>
            <div className={styles.inputGroup}>
              <label>To</label>
              <input
                type="date"
                value={toDate || ''}
                onChange={(e) => onChange(fromDate, e.target.value)}
                className={styles.dateInput}
              />
            </div>
          </div>

          <div className={styles.actions}>
            <button className={styles.clearAllBtn} onClick={handleClear}>
              Clear
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
