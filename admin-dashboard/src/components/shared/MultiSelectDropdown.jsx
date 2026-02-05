import { useState, useEffect, useRef } from 'react'
import styles from './MultiSelectDropdown.module.css'

export default function MultiSelectDropdown({ label, options, selected, onChange, placeholder }) {
  const [open, setOpen] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    function handleClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  function toggle(val) {
    const next = selected.includes(val) ? selected.filter((v) => v !== val) : [...selected, val]
    onChange(next)
  }

  function clearAll(e) {
    e.stopPropagation()
    onChange([])
  }

  const displayLabel = placeholder || label

  return (
    <div className={styles.multiSelect} ref={ref}>
      <button className={styles.multiSelectBtn} onClick={() => setOpen(!open)}>
        {displayLabel}{selected.length > 0 ? ` (${selected.length})` : ''}
        {selected.length > 0 && (
          <span className={styles.clearBtn} onClick={clearAll} title="Clear all">
            ×
          </span>
        )}
        <span className={styles.multiSelectArrow}>{open ? '\u25B2' : '\u25BC'}</span>
      </button>
      {open && (
        <div className={styles.multiSelectDropdown}>
          {options.map((opt) => {
            const value = typeof opt === 'object' ? opt.value : opt
            const label = typeof opt === 'object' ? opt.label : opt
            return (
              <label key={value} className={styles.multiSelectOption}>
                <input
                  type="checkbox"
                  checked={selected.includes(value)}
                  onChange={() => toggle(value)}
                />
                {label}
              </label>
            )
          })}
        </div>
      )}
    </div>
  )
}
