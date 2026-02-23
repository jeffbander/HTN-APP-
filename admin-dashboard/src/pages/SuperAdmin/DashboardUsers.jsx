import { useState, useEffect, useCallback } from 'react'
import { fetchApi } from '../../api/client'
import Header from '../../components/layout/Header'
import Badge from '../../components/shared/Badge'
import Modal from '../../components/shared/Modal'
import styles from './DashboardUsers.module.css'

const ROLE_OPTIONS = [
  { value: 'super_admin', label: 'Super Admin', color: 'blue' },
  { value: 'union_leader', label: 'Union Leader', color: 'teal' },
  { value: 'shipping_company', label: 'Shipping', color: 'orange' },
  { value: 'nurse_coach', label: 'Nurse Coach', color: 'purple' },
]

export default function DashboardUsers() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [form, setForm] = useState({ name: '', email: '', role: 'nurse_coach' })
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    try {
      const data = await fetchApi('/super-admin/dashboard-users')
      setUsers(data)
    } catch {
      // ignore
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const handleCreate = async (e) => {
    e.preventDefault()
    setError('')
    setSaving(true)
    try {
      await fetchApi('/super-admin/dashboard-users', {
        method: 'POST',
        body: JSON.stringify(form),
      })
      setShowCreate(false)
      setForm({ name: '', email: '', role: 'nurse_coach' })
      load()
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  const toggleActive = async (user) => {
    try {
      await fetchApi(`/super-admin/dashboard-users/${user.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: !user.is_active }),
      })
      load()
    } catch {
      // ignore
    }
  }

  const updateRole = async (user, newRole) => {
    try {
      await fetchApi(`/super-admin/dashboard-users/${user.id}`, {
        method: 'PUT',
        body: JSON.stringify({ role: newRole }),
      })
      load()
    } catch {
      // ignore
    }
  }

  const roleOption = (role) => ROLE_OPTIONS.find((r) => r.value === role)

  if (loading) return <><Header title="Dashboard Users" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Dashboard Users" />
      <div className={styles.toolbar}>
        <span className={styles.count}>{users.length} users</span>
        <button className={styles.createBtn} onClick={() => setShowCreate(true)}>
          + Add User
        </button>
      </div>

      <div className={styles.table}>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>MFA</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className={!u.is_active ? styles.inactive : ''}>
                <td className={styles.name}>{u.name}</td>
                <td>{u.email}</td>
                <td>
                  <Badge color={roleOption(u.role)?.color || 'gray'}>
                    {roleOption(u.role)?.label || u.role}
                  </Badge>
                </td>
                <td>
                  <Badge color={u.is_mfa_enabled ? 'green' : 'gray'}>
                    {u.is_mfa_enabled ? 'Enabled' : 'Not set'}
                  </Badge>
                </td>
                <td>
                  <Badge color={u.is_active ? 'green' : 'red'}>
                    {u.is_active ? 'Active' : 'Inactive'}
                  </Badge>
                </td>
                <td className={styles.date}>
                  {u.created_at ? new Date(u.created_at).toLocaleDateString() : '—'}
                </td>
                <td>
                  <div className={styles.actions}>
                    <select
                      className={styles.roleSelect}
                      value={u.role}
                      onChange={(e) => updateRole(u, e.target.value)}
                    >
                      {ROLE_OPTIONS.map((r) => (
                        <option key={r.value} value={r.value}>{r.label}</option>
                      ))}
                    </select>
                    <button
                      className={u.is_active ? styles.deactivateBtn : styles.activateBtn}
                      onClick={() => toggleActive(u)}
                    >
                      {u.is_active ? 'Deactivate' : 'Activate'}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showCreate && (
        <Modal title="Add Dashboard User" onClose={() => setShowCreate(false)}>
          <form onSubmit={handleCreate}>
            {error && <div className={styles.error}>{error}</div>}
            <div className={styles.field}>
              <label>Name</label>
              <input
                type="text"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                required
              />
            </div>
            <div className={styles.field}>
              <label>Email</label>
              <input
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                required
              />
            </div>
            <div className={styles.field}>
              <label>Role</label>
              <select
                value={form.role}
                onChange={(e) => setForm({ ...form, role: e.target.value })}
              >
                {ROLE_OPTIONS.map((r) => (
                  <option key={r.value} value={r.value}>{r.label}</option>
                ))}
              </select>
            </div>
            <button className={styles.submitBtn} type="submit" disabled={saving}>
              {saving ? 'Creating...' : 'Create User'}
            </button>
          </form>
        </Modal>
      )}
    </>
  )
}
