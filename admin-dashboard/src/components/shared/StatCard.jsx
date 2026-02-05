import styles from './StatCard.module.css'

export default function StatCard({ icon, iconBg, label, value, change, changeType }) {
  return (
    <div className={styles.card}>
      {icon && (
        <div className={styles.icon} style={{ background: iconBg }}>
          {icon}
        </div>
      )}
      <div className={styles.label}>{label}</div>
      <div className={styles.value}>{value}</div>
      {change && (
        <div className={`${styles.change} ${styles[changeType] || ''}`}>{change}</div>
      )}
    </div>
  )
}
