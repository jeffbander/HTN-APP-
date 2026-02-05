import { useState, useRef, useEffect } from 'react'
import styles from './SearchInput.module.css'

export default function SearchInput({ value, onChange, placeholder, debounceMs = 300 }) {
  const [localValue, setLocalValue] = useState(value || '')
  const debounceRef = useRef(null)

  useEffect(() => {
    setLocalValue(value || '')
  }, [value])

  function handleChange(e) {
    const val = e.target.value
    setLocalValue(val)

    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => {
      onChange(val)
    }, debounceMs)
  }

  function handleClear() {
    setLocalValue('')
    clearTimeout(debounceRef.current)
    onChange('')
  }

  return (
    <div className={styles.container}>
      <span className={styles.searchIcon}>🔍</span>
      <input
        type="text"
        className={styles.input}
        placeholder={placeholder || 'Search...'}
        value={localValue}
        onChange={handleChange}
      />
      {localValue && (
        <button className={styles.clearBtn} onClick={handleClear}>
          ×
        </button>
      )}
    </div>
  )
}
