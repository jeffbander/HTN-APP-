import { useState, useEffect, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { fetchApi } from '../../api/client'
import Header from '../../components/layout/Header'
import Badge from '../../components/shared/Badge'
import SearchInput from '../../components/shared/SearchInput'
import { classifyBP } from '../../utils/bpCategory'
import styles from './Patients.module.css'

export default function Patients() {
  const [patients, setPatients] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')

  const load = useCallback(async () => {
    try {
      const data = await fetchApi('/nurse/patients')
      setPatients(data)
    } catch {
      // ignore
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = patients.filter((p) => {
    if (!search) return true
    const q = search.toLowerCase()
    return (p.name || '').toLowerCase().includes(q) ||
           (p.email || '').toLowerCase().includes(q) ||
           String(p.id).includes(q)
  })

  if (loading) return <><Header title="Patients" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Patients" />
      <div className={styles.toolbar}>
        <SearchInput value={search} onChange={setSearch} placeholder="Search patients..." />
        <span className={styles.count}>{filtered.length} patients</span>
      </div>
      <div className={styles.grid}>
        {filtered.map((p) => {
          const bp = p.latest_systolic && p.latest_diastolic
            ? classifyBP(p.latest_systolic, p.latest_diastolic)
            : null
          return (
            <Link key={p.id} to={`/patients/${p.id}`} className={styles.card}>
              <div className={styles.cardTop}>
                <span className={styles.name}>{p.name || `User #${p.id}`}</span>
                {p.is_flagged && <Badge color="red">Flagged</Badge>}
              </div>
              <div className={styles.detail}>{p.email}</div>
              <div className={styles.detail}>
                Status: <Badge color={p.user_status === 'active' ? 'green' : 'gray'}>
                  {(p.user_status || 'unknown').replace(/_/g, ' ')}
                </Badge>
              </div>
              {bp && (
                <div className={styles.bp}>
                  <span className={styles.bpValue}>{p.latest_systolic}/{p.latest_diastolic}</span>
                  <Badge color={bp.css === 'normal' ? 'green' : bp.css === 'elevated' ? 'orange' : 'red'}>
                    {bp.label}
                  </Badge>
                </div>
              )}
            </Link>
          )
        })}
        {filtered.length === 0 && (
          <div className={styles.empty}>No patients found.</div>
        )}
      </div>
    </>
  )
}
