import { Link } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import styles from './Header.module.css'

export default function Header({ title, backLink, backLabel }) {
  const { email, logout } = useAuth()

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
        <span className={styles.user}>{email}</span>
        <button className={styles.logoutBtn} onClick={logout}>
          Logout
        </button>
      </div>
    </header>
  )
}
