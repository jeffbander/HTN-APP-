import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import DateRangeFilter from '../components/shared/DateRangeFilter'
import MultiSelectDropdown from '../components/shared/MultiSelectDropdown'
import SearchInput from '../components/shared/SearchInput'
import ExportButton from '../components/shared/ExportButton'
import styles from './CallReports.module.css'

const OUTCOME_COLORS = {
  completed: { bg: '#e8f5e9', color: '#2e7d32' },
  left_vm: { bg: '#fff3e0', color: '#e65100' },
  no_answer: { bg: '#fafafa', color: '#666' },
  email_sent: { bg: '#e3f2fd', color: '#1565c0' },
  requested_callback: { bg: '#f3e5f5', color: '#7b1fa2' },
  refused: { bg: '#ffebee', color: '#c62828' },
  sent_materials: { bg: '#e0f7fa', color: '#00695c' },
}

const LIST_TYPE_LABELS = {
  nurse: 'Nurse',
  coach: 'HTN Coach',
  no_reading: 'No-Reading',
}

const OUTCOME_OPTIONS = [
  { value: 'completed', label: 'Completed' },
  { value: 'left_vm', label: 'Left VM' },
  { value: 'no_answer', label: 'No Answer' },
  { value: 'email_sent', label: 'Email Sent' },
  { value: 'requested_callback', label: 'Requested Callback' },
  { value: 'refused', label: 'Refused' },
  { value: 'sent_materials', label: 'Sent Materials' },
]

const LIST_TYPE_OPTIONS = [
  { value: 'nurse', label: 'Nurse' },
  { value: 'coach', label: 'HTN Coach' },
  { value: 'no_reading', label: 'No-Reading' },
]

export default function CallReports() {
  const [attempts, setAttempts] = useState([])
  const [filteredAttempts, setFilteredAttempts] = useState([])
  const [summary, setSummary] = useState({ total_all: 0, total_week: 0, by_outcome: {} })
  const [loading, setLoading] = useState(true)

  // Filters
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [listTypeFilter, setListTypeFilter] = useState([])
  const [outcomeFilter, setOutcomeFilter] = useState([])
  const [patientSearch, setPatientSearch] = useState('')

  async function loadData() {
    setLoading(true)
    try {
      const params = new URLSearchParams()
      if (dateFrom) params.set('date_from', dateFrom)
      if (dateTo) params.set('date_to', dateTo)
      if (listTypeFilter.length === 1) params.set('list_type', listTypeFilter[0])
      if (outcomeFilter.length === 1) params.set('outcome', outcomeFilter[0])

      const data = await fetchApi(`/admin/call-reports?${params.toString()}`)
      setAttempts(data.attempts || [])
      setSummary(data.summary || { total_all: 0, total_week: 0, by_outcome: {} })
    } catch {
      // fail gracefully
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [dateFrom, dateTo, listTypeFilter, outcomeFilter])

  // Client-side filter for patient name search and multi-select filters
  useEffect(() => {
    let filtered = attempts

    if (patientSearch) {
      const searchLower = patientSearch.toLowerCase()
      filtered = filtered.filter(a =>
        (a.patient_name || '').toLowerCase().includes(searchLower)
      )
    }

    if (listTypeFilter.length > 1) {
      filtered = filtered.filter(a => listTypeFilter.includes(a.list_type))
    }

    if (outcomeFilter.length > 1) {
      filtered = filtered.filter(a => outcomeFilter.includes(a.outcome))
    }

    setFilteredAttempts(filtered)
  }, [attempts, patientSearch, listTypeFilter, outcomeFilter])

  function handleClear() {
    setDateFrom('')
    setDateTo('')
    setListTypeFilter([])
    setOutcomeFilter([])
    setPatientSearch('')
  }

  async function handleExport() {
    const params = new URLSearchParams()
    if (dateFrom) params.set('date_from', dateFrom)
    if (dateTo) params.set('date_to', dateTo)
    if (listTypeFilter.length === 1) params.set('list_type', listTypeFilter[0])
    if (outcomeFilter.length === 1) params.set('outcome', outcomeFilter[0])

    const token = localStorage.getItem('token')
    const response = await fetch(`${import.meta.env.VITE_API_URL || ''}/admin/export/call-reports?${params}`, {
      headers: { Authorization: `Bearer ${token}` }
    })

    if (!response.ok) throw new Error('Export failed')

    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `call_reports_export_${new Date().toISOString().split('T')[0]}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  function formatDateTime(iso) {
    if (!iso) return '\u2014'
    return new Date(iso).toLocaleString('en-US', {
      month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
    })
  }

  if (loading) return <><Header title="Call Reports" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Call Reports" />

      {/* Summary Stats */}
      <div className={styles.summaryRow}>
        <div className={styles.summaryCard}>
          <div className={styles.summaryLabel}>Total Calls</div>
          <div className={styles.summaryValue}>{summary.total_all}</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryLabel}>This Week</div>
          <div className={styles.summaryValue}>{summary.total_week}</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryLabel}>Completed</div>
          <div className={styles.summaryValue} style={{ color: '#2e7d32' }}>{summary.by_outcome?.completed || 0}</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryLabel}>Left VM</div>
          <div className={styles.summaryValue} style={{ color: '#e65100' }}>{summary.by_outcome?.left_vm || 0}</div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryLabel}>No Answer</div>
          <div className={styles.summaryValue} style={{ color: '#666' }}>{summary.by_outcome?.no_answer || 0}</div>
        </div>
      </div>

      {/* Filters */}
      <div className={styles.filters}>
        <SearchInput
          value={patientSearch}
          onChange={setPatientSearch}
          placeholder="Search patient name..."
        />
        <DateRangeFilter
          label="Date Range"
          fromDate={dateFrom}
          toDate={dateTo}
          onChange={(from, to) => { setDateFrom(from); setDateTo(to) }}
        />
        <MultiSelectDropdown
          label="List Type"
          options={LIST_TYPE_OPTIONS}
          selected={listTypeFilter}
          onChange={setListTypeFilter}
        />
        <MultiSelectDropdown
          label="Outcome"
          options={OUTCOME_OPTIONS}
          selected={outcomeFilter}
          onChange={setOutcomeFilter}
        />
        <button className={styles.clearBtn} onClick={handleClear}>Clear</button>
        <ExportButton onClick={handleExport} label="Export CSV" />
      </div>

      {/* Table */}
      <div className={styles.tableCard}>
        <div className={styles.tableHeader}>
          <span className={styles.tableTitle}>Call Attempts ({filteredAttempts.length})</span>
        </div>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Date</th>
              <th>Patient</th>
              <th>List</th>
              <th>Caller</th>
              <th>Outcome</th>
              <th>Notes</th>
              <th>Follow-up</th>
            </tr>
          </thead>
          <tbody>
            {filteredAttempts.map((a) => {
              const oc = OUTCOME_COLORS[a.outcome] || { bg: '#f5f5f5', color: '#666' }
              return (
                <tr key={a.id}>
                  <td>{formatDateTime(a.created_at)}</td>
                  <td>
                    <Link to={`/users/${a.user_id}`} className={styles.patientLink}>
                      {a.patient_name || `User #${a.user_id}`}
                    </Link>
                  </td>
                  <td>
                    <span className={styles.listTypeBadge}>
                      {LIST_TYPE_LABELS[a.list_type] || a.list_type || '\u2014'}
                    </span>
                  </td>
                  <td>{a.admin_name || 'Admin'}</td>
                  <td>
                    <span className={styles.outcomeBadge} style={{ background: oc.bg, color: oc.color }}>
                      {a.outcome?.replace(/_/g, ' ')}
                    </span>
                  </td>
                  <td>
                    <div className={styles.notesTruncated} title={a.notes || ''}>
                      {a.notes ? (a.notes.length > 60 ? a.notes.slice(0, 60) + '...' : a.notes) : '\u2014'}
                    </div>
                  </td>
                  <td>{a.follow_up_date ? formatDateTime(a.follow_up_date) : '\u2014'}</td>
                </tr>
              )
            })}
            {filteredAttempts.length === 0 && (
              <tr>
                <td colSpan={7} className={styles.empty}>No call attempts found matching the current filters.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  )
}
