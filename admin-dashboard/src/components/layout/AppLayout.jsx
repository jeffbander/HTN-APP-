import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import styles from './AppLayout.module.css'

export default function AppLayout({ badges }) {
  return (
    <div className={styles.layout}>
      <Sidebar badges={badges} />
      <main className={styles.main}>
        <Outlet />
      </main>
    </div>
  )
}
