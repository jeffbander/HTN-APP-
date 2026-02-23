import styles from './TabBar.module.css'

export default function TabBar({ tabs, active, onChange }) {
  return (
    <div className={styles.tabBar}>
      {tabs.map((tab) => (
        <button
          key={tab.key}
          className={`${styles.tab} ${active === tab.key ? styles.active : ''}`}
          onClick={() => onChange(tab.key)}
        >
          {tab.label}
          {tab.count != null && (
            <span className={styles.count}>{tab.count}</span>
          )}
        </button>
      ))}
    </div>
  )
}
