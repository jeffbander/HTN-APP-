import { useState, useEffect, useRef } from 'react'
import styles from './RangeFilter.module.css'

export default function RangeFilter({ label, minValue, maxValue, onChange, minPlaceholder, maxPlaceholder, unit }) {
  const [open, setOpen] = useState(false)
  const [localMin, setLocalMin] = useState(minValue || '')
  const [localMax, setLocalMax] = useState(maxValue || '')
  const ref = useRef(null)

  useEffect(() => {
    setLocalMin(minValue || '')
    setLocalMax(maxValue || '')
  }, [minValue, maxValue])

  useEffect(() => {
    function handleClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  function handleApply() {
    onChange(localMin || null, localMax || null)
    setOpen(false)
  }

  function handleClear() {
    setLocalMin('')
    setLocalMax('')
    onChange(null, null)
    setOpen(false)
  }

  const hasValue = minValue || maxValue
  const displayText = hasValue
    ? `${minValue || '*'} - ${maxValue || '*'}${unit ? ` ${unit}` : ''}`
    : label

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
          <div className={styles.inputRow}>
            <div className={styles.inputGroup}>
              <label>Min</label>
              <input
                type="number"
                value={localMin}
                onChange={(e) => setLocalMin(e.target.value)}
                placeholder={minPlaceholder || 'Min'}
                className={styles.numberInput}
              />
            </div>
            <span className={styles.separator}>-</span>
            <div className={styles.inputGroup}>
              <label>Max</label>
              <input
                type="number"
                value={localMax}
                onChange={(e) => setLocalMax(e.target.value)}
                placeholder={maxPlaceholder || 'Max'}
                className={styles.numberInput}
              />
            </div>
          </div>

          <div className={styles.actions}>
            <button className={styles.clearAllBtn} onClick={handleClear}>
              Clear
            </button>
            <button className={styles.applyBtn} onClick={handleApply}>
              Apply
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
