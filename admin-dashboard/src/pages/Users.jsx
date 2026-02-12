import { useState, useEffect, useCallback } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import Badge from '../components/shared/Badge'
import Pagination from '../components/shared/Pagination'
import Modal from '../components/shared/Modal'
import SearchInput from '../components/shared/SearchInput'
import BulkSelectionBar from '../components/shared/BulkSelectionBar'
import ExportButton from '../components/shared/ExportButton'
import styles from './Users.module.css'

const TABS = [
  { key: 'all', label: 'All Users', color: null },
  { key: 'active', label: 'Active', color: 'green' },
  { key: 'pending_approval', label: 'Pending Approval', color: 'orange' },
  { key: 'pending_registration', label: 'Pending Registration', color: 'orange' },
  { key: 'pending_cuff', label: 'Pending Cuff', color: 'orange' },
  { key: 'pending_first_reading', label: 'Pending First Reading', color: 'blue' },
  { key: 'enrollment_only', label: 'Enrollment Only', color: 'gray' },
  { key: 'deactivated', label: 'Deactivated', color: 'red' },
]

const STATUS_DISPLAY = {
  pending_approval: { label: 'Pending Approval', color: 'orange' },
  pending_registration: { label: 'Pending Registration', color: 'orange' },
  pending_cuff: { label: 'Pending Cuff', color: 'orange' },
  pending_first_reading: { label: 'Pending First Reading', color: 'blue' },
  active: { label: 'Active', color: 'green' },
  deactivated: { label: 'Deactivated', color: 'red' },
  enrollment_only: { label: 'Enrollment Only', color: 'gray' },
}

const GENDER_OPTIONS = ['Male', 'Female', 'Prefer not to say']
const HTN_OPTIONS = [
  { value: '', label: 'All' },
  { value: 'true', label: 'Yes' },
  { value: 'false', label: 'No' },
]

export default function Users() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [users, setUsers] = useState([])
  const [totalCount, setTotalCount] = useState(0)
  const [tabCounts, setTabCounts] = useState({})
  const [activeTab, setActiveTab] = useState(searchParams.get('tab') || 'all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [modal, setModal] = useState(null)
  const [sortBy, setSortBy] = useState('created_at')
  const [sortDir, setSortDir] = useState('desc')

  // Filters
  const [genderFilter, setGenderFilter] = useState('')
  const [unionFilter, setUnionFilter] = useState('')
  const [htnFilter, setHtnFilter] = useState('')
  const [unions, setUnions] = useState([])

  // Bulk selection
  const [selectedIds, setSelectedIds] = useState(new Set())
  const [bulkLoading, setBulkLoading] = useState(false)

  const perPage = 50

  // Load tab counts
  const loadTabCounts = useCallback(async () => {
    try {
      const data = await fetchApi('/admin/users/tab-counts')
      setTabCounts(data)
    } catch {
      // ignore
    }
  }, [])

  // Load users for current tab
  const loadUsers = useCallback(async (searchVal) => {
    setLoading(true)
    setError(null)
    try {
      const params = new URLSearchParams({
        page,
        per_page: perPage,
        sort: sortBy,
        dir: sortDir,
      })
      if (searchVal) params.set('search', searchVal)
      if (unionFilter) params.set('union_id', unionFilter)
      if (genderFilter) params.set('gender', genderFilter)
      if (htnFilter) params.set('has_htn', htnFilter)

      const data = await fetchApi(`/admin/users/tab/${activeTab}?${params}`)
      setUsers(data.users || [])
      setTotalCount(data.total || 0)
    } catch (err) {
      setError(err.message || 'Failed to load users')
      setUsers([])
    } finally {
      setLoading(false)
    }
  }, [activeTab, page, sortBy, sortDir, unionFilter, genderFilter, htnFilter])

  useEffect(() => {
    loadUsers(search)
  }, [activeTab, page, sortBy, sortDir, unionFilter, genderFilter, htnFilter])

  useEffect(() => {
    loadTabCounts()
  }, [])

  // Load unions for filter dropdown
  useEffect(() => {
    fetchApi('/admin/unions').then(data => {
      setUnions(data.unions || [])
    }).catch(() => {})
  }, [])

  function handleTabChange(tab) {
    setActiveTab(tab)
    setPage(1)
    setSelectedIds(new Set())
  }

  function handleSearchChange(val) {
    setSearch(val)
    setPage(1)
    loadUsers(val)
  }

  function handleSort(col) {
    if (sortBy === col) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    } else {
      setSortBy(col)
      setSortDir('asc')
    }
    setPage(1)
  }

  function sortArrow(col) {
    if (sortBy !== col) return ''
    return sortDir === 'asc' ? ' \u25B2' : ' \u25BC'
  }

  function statusDisplay(u) {
    const s = STATUS_DISPLAY[u.user_status]
    if (s) return s
    return { label: u.user_status || 'Unknown', color: 'gray' }
  }

  async function handleApprove(user) {
    try {
      await fetchApi(`/admin/users/${user.id}/approve`, { method: 'PUT' })
      setModal(null)
      loadUsers(search)
      loadTabCounts()
    } catch (err) {
      alert(err.message)
    }
  }

  async function handleDeactivate(user) {
    try {
      await fetchApi(`/admin/users/${user.id}/deactivate`, { method: 'PUT' })
      setModal(null)
      loadUsers(search)
      loadTabCounts()
    } catch (err) {
      alert(err.message)
    }
  }

  // Bulk operations
  function toggleSelect(id) {
    const next = new Set(selectedIds)
    if (next.has(id)) {
      next.delete(id)
    } else {
      next.add(id)
    }
    setSelectedIds(next)
  }

  function selectAll() {
    setSelectedIds(new Set(users.map(u => u.id)))
  }

  function deselectAll() {
    setSelectedIds(new Set())
  }

  async function handleBulkApprove() {
    if (selectedIds.size === 0) return
    setBulkLoading(true)
    try {
      const result = await fetchApi('/admin/users/bulk-approve', {
        method: 'POST',
        body: JSON.stringify({ user_ids: Array.from(selectedIds) })
      })
      alert(`Approved ${result.results.success.length} users. ${result.results.skipped.length} skipped. ${result.results.error.length} errors.`)
      setSelectedIds(new Set())
      loadUsers(search)
      loadTabCounts()
    } catch (err) {
      alert(err.message)
    } finally {
      setBulkLoading(false)
    }
  }

  async function handleBulkDeactivate() {
    if (selectedIds.size === 0) return
    setBulkLoading(true)
    try {
      const result = await fetchApi('/admin/users/bulk-deactivate', {
        method: 'POST',
        body: JSON.stringify({ user_ids: Array.from(selectedIds) })
      })
      alert(`Deactivated ${result.results.success.length} users. ${result.results.skipped.length} skipped. ${result.results.error.length} errors.`)
      setSelectedIds(new Set())
      loadUsers(search)
      loadTabCounts()
    } catch (err) {
      alert(err.message)
    } finally {
      setBulkLoading(false)
    }
  }

  async function handleExport() {
    const params = new URLSearchParams()
    if (activeTab !== 'all') params.set('status', activeTab)
    if (genderFilter) params.set('gender', genderFilter)
    if (unionFilter) params.set('union_id', unionFilter)
    if (htnFilter) params.set('has_htn', htnFilter)

    const token = localStorage.getItem('htn_admin_token')
    const response = await fetch(`${import.meta.env.VITE_API_URL || ''}/admin/export/users?${params}`, {
      headers: { Authorization: `Bearer ${token}` }
    })

    if (!response.ok) throw new Error('Export failed')

    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `users_export_${new Date().toISOString().split('T')[0]}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  function formatDate(iso) {
    if (!iso) return '\u2014'
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  // Convert page-based to offset-based for Pagination component
  const offset = (page - 1) * perPage

  return (
    <>
      <Header title="User Management" />

      {/* Tab bar */}
      <div className={styles.tabBar}>
        {TABS.map((tab) => (
          <button
            key={tab.key}
            className={`${styles.tab} ${activeTab === tab.key ? styles.tabActive : ''}`}
            onClick={() => handleTabChange(tab.key)}
          >
            <span className={styles.tabLabel}>{tab.label}</span>
            {tabCounts[tab.key] != null && (
              <span className={`${styles.tabBadge} ${styles[`badge_${tab.color}`] || ''}`}>
                {tabCounts[tab.key]}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Filters toolbar */}
      <div className={styles.toolbar}>
        <SearchInput
          value={search}
          onChange={handleSearchChange}
          placeholder="Search by name or email..."
        />

        <div className={styles.filterGroup}>
          <select
            value={unionFilter}
            onChange={(e) => { setUnionFilter(e.target.value); setPage(1) }}
            className={styles.select}
          >
            <option value="">All Unions</option>
            {unions.map((u) => (
              <option key={u.id} value={u.id}>{u.name}</option>
            ))}
          </select>

          <select
            value={genderFilter}
            onChange={(e) => { setGenderFilter(e.target.value); setPage(1) }}
            className={styles.select}
          >
            <option value="">All Genders</option>
            {GENDER_OPTIONS.map((g) => (
              <option key={g} value={g}>{g}</option>
            ))}
          </select>

          <select
            value={htnFilter}
            onChange={(e) => { setHtnFilter(e.target.value); setPage(1) }}
            className={styles.select}
          >
            <option value="">Has HTN: All</option>
            <option value="true">Has HTN: Yes</option>
            <option value="false">Has HTN: No</option>
          </select>
        </div>

        <span className={styles.resultCount}>
          {totalCount} user{totalCount !== 1 ? 's' : ''}
        </span>
        <ExportButton onClick={handleExport} label="Export CSV" />
      </div>

      {error && (
        <div className={styles.errorBanner}>
          Failed to load users: {error}
          <button className={styles.retryBtn} onClick={() => loadUsers(search)}>Retry</button>
        </div>
      )}

      <div className={styles.card}>
        {loading ? (
          <div className={styles.loading}>Loading...</div>
        ) : (
          <>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th style={{ width: 40 }}>
                    <input
                      type="checkbox"
                      checked={selectedIds.size === users.length && users.length > 0}
                      onChange={(e) => e.target.checked ? selectAll() : deselectAll()}
                    />
                  </th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('created_at')}>
                    Name{sortArrow('created_at')}
                  </th>
                  <th>Email</th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('union_id')}>
                    Union{sortArrow('union_id')}
                  </th>
                  <th>Status</th>
                  <th>Last Reading</th>
                  <th>Readings</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const st = statusDisplay(u)
                  return (
                    <tr key={u.id} className={styles.clickableRow} onClick={() => navigate(`/users/${u.id}`)}>
                      <td onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={selectedIds.has(u.id)}
                          onChange={() => toggleSelect(u.id)}
                        />
                      </td>
                      <td>
                        <Link to={`/users/${u.id}`} className={styles.nameLink} onClick={(e) => e.stopPropagation()}>
                          {u.name || '\u2014'}
                        </Link>
                      </td>
                      <td>{u.email || '\u2014'}</td>
                      <td>{u.union_name || '\u2014'}</td>
                      <td><Badge color={st.color}>{st.label}</Badge></td>
                      <td>{formatDate(u.last_reading_date)}</td>
                      <td>{u.reading_count || 0}</td>
                      <td onClick={(e) => e.stopPropagation()}>
                        {u.user_status === 'deactivated' ? (
                          <button className={`${styles.actionBtn} ${styles.btnDisabled}`} disabled>
                            Deactivated
                          </button>
                        ) : u.user_status === 'pending_approval' ? (
                          <button
                            className={`${styles.actionBtn} ${styles.btnApprove}`}
                            onClick={() => setModal({ type: 'approve', user: u })}
                          >
                            Approve
                          </button>
                        ) : (
                          <button
                            className={`${styles.actionBtn} ${styles.btnDeactivate}`}
                            onClick={() => setModal({ type: 'deactivate', user: u })}
                          >
                            Deactivate
                          </button>
                        )}
                      </td>
                    </tr>
                  )
                })}
                {users.length === 0 && !error && (
                  <tr>
                    <td colSpan={8} style={{ textAlign: 'center', color: '#999', padding: 32 }}>
                      No users found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
            <Pagination
              offset={offset}
              limit={perPage}
              total={totalCount}
              onChange={(newOffset) => setPage(Math.floor(newOffset / perPage) + 1)}
            />
          </>
        )}
      </div>

      <BulkSelectionBar
        selectedCount={selectedIds.size}
        totalCount={users.length}
        onSelectAll={selectAll}
        onDeselectAll={deselectAll}
        loading={bulkLoading}
        actions={[
          { label: 'Approve Selected', onClick: handleBulkApprove, icon: '\u2713' },
          { label: 'Deactivate Selected', onClick: handleBulkDeactivate, variant: 'danger', icon: '\u2715' },
        ]}
      />

      <Modal
        open={modal?.type === 'approve'}
        title="Approve User"
        confirmLabel="Approve User"
        confirmColor="#4caf50"
        onCancel={() => setModal(null)}
        onConfirm={() => handleApprove(modal.user)}
      >
        <p>
          Are you sure you want to approve <strong>{modal?.user?.name}</strong> ({modal?.user?.email})?
          They will be moved to Pending Registration status.
        </p>
      </Modal>

      <Modal
        open={modal?.type === 'deactivate'}
        title="Deactivate User"
        confirmLabel="Deactivate User"
        confirmColor="#f44336"
        onCancel={() => setModal(null)}
        onConfirm={() => handleDeactivate(modal.user)}
      >
        <p>
          Are you sure you want to deactivate <strong>{modal?.user?.name}</strong> ({modal?.user?.email})?
          They will no longer be able to log in.
        </p>
      </Modal>
    </>
  )
}
