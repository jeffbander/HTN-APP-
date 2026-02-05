import styles from './SidePanel.module.css'

export default function SidePanel({ open, title, onClose, children, width = 420 }) {
  if (!open) return null

  return (
    <div className={styles.backdrop} onClick={onClose}>
      <div
        className={styles.panel}
        style={{ width }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={styles.panelHeader}>
          <div className={styles.panelTitle}>{title}</div>
          <button className={styles.closeBtn} onClick={onClose}>&times;</button>
        </div>
        <div className={styles.panelBody}>
          {children}
        </div>
      </div>
    </div>
  )
}
