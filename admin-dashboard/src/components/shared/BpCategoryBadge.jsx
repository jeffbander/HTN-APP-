import { classifyBP } from '../../utils/bpCategory'
import styles from './BpCategoryBadge.module.css'

export default function BpCategoryBadge({ systolic, diastolic }) {
  const cat = classifyBP(systolic, diastolic)
  return (
    <span className={`${styles.badge} ${styles[cat.css]}`}>
      {cat.label === 'Crisis' ? 'CRISIS' : cat.label}
    </span>
  )
}
