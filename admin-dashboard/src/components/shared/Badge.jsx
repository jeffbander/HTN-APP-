import styles from './Badge.module.css'

const colorMap = {
  green: styles.green,
  orange: styles.orange,
  red: styles.red,
  blue: styles.blue,
  gray: styles.gray,
}

export default function Badge({ children, color = 'gray' }) {
  return (
    <span className={`${styles.badge} ${colorMap[color] || ''}`}>
      {children}
    </span>
  )
}
