import { Link } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import Badge from '../shared/Badge'
import styles from './Header.module.css'

const ROLE_LABELS = {
  super_admin: 'Super Admin',
  union_leader: 'Union Leader',
  shipping_company: 'Shipping',
  nurse_coach: 'Nurse Coach',
}

const ROLE_BADGE_COLOR = {
  super_admin: 'blue',
  union_leader: 'green',
  shipping_company: 'orange',
  nurse_coach: 'purple',
}

export default function Header({ title, backLink, backLabel }) {
  const { email, userName, role, logout } = useAuth()

  return (
    <header className={styles.header}>
      <div className={styles.left}>
        {backLink && (
          <Link className={styles.backBtn} to={backLink}>
            &larr; {backLabel || 'Back'}
          </Link>
        )}
        <h1 className={styles.title}>{title}</h1>
      </div>
      <div className={styles.right}>
        {role && (
          <Badge color={ROLE_BADGE_COLOR[role] || 'gray'}>
            {ROLE_LABELS[role] || role}
          </Badge>
        )}
        <span className={styles.user}>{userName || email}</span>
        <button className={styles.logoutBtn} onClick={logout}>
          Logout
        </button>
      </div>
    </header>
  )
}
