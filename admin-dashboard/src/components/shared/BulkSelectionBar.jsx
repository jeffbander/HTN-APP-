import styles from './BulkSelectionBar.module.css'

export default function BulkSelectionBar({ selectedCount, totalCount, onSelectAll, onDeselectAll, actions, loading }) {
  if (selectedCount === 0) return null

  return (
    <div className={styles.bar}>
      <div className={styles.info}>
        <span className={styles.count}>{selectedCount}</span> selected
        {totalCount && (
          <span className={styles.total}> of {totalCount}</span>
        )}
      </div>

      <div className={styles.toggles}>
        {onSelectAll && (
          <button className={styles.toggleBtn} onClick={onSelectAll}>
            Select All
          </button>
        )}
        {onDeselectAll && (
          <button className={styles.toggleBtn} onClick={onDeselectAll}>
            Deselect All
          </button>
        )}
      </div>

      <div className={styles.actions}>
        {actions.map((action, idx) => (
          <button
            key={idx}
            className={`${styles.actionBtn} ${action.variant === 'danger' ? styles.danger : ''}`}
            onClick={action.onClick}
            disabled={loading}
          >
            {action.icon && <span className={styles.icon}>{action.icon}</span>}
            {action.label}
          </button>
        ))}
      </div>

      {loading && (
        <div className={styles.loadingOverlay}>
          <span className={styles.spinner} />
          Processing...
        </div>
      )}
    </div>
  )
}
