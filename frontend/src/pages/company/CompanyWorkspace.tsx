import { useQuery } from '@tanstack/react-query'
import { Link, Navigate, useParams } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { companyService, dashboardService } from '../../services/companyService'

const money = (amount: number, currency: string) =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(amount)

const shortDate = (value: string) =>
  new Date(`${value}T00:00:00`).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })

export default function CompanyWorkspace() {
  const { companyId } = useParams()
  const { session, user, signOut } = useAuth()

  const companies = useQuery({
    queryKey: ['companies', user?.id],
    queryFn: () => companyService.list(session!.access_token),
    enabled: Boolean(session),
  })

  const dashboard = useQuery({
    queryKey: ['company-dashboard', companyId],
    queryFn: () =>
      dashboardService.get(session!.access_token, companyId!),
    enabled: Boolean(session && companyId),
  })

  if (!session) {
    return <Navigate to="/login" replace />
  }

  if (companies.isPending) {
    return <div className="screen-state">Loading company…</div>
  }

  const company = companies.data?.find(
    item => item.id === companyId
  )

  if (!company) {
    return <Navigate to="/companies" replace />
  }

  const data = dashboard.data

  return (
    <main className="app-shell">

      {/* Navigation */}
      <header className="topbar">
        <Link className="brand" to="/companies">
          LITE<span>BOOKS</span>
        </Link>

        <nav className="top-nav">
          <Link
            className="nav-link active"
            to={`/company/${company.id}`}
          >
            Dashboard
          </Link>

          <Link
            className="nav-link"
            to={`/company/${company.id}/inventory`}
          >
            Inventory
          </Link>

          <Link
            className="nav-link"
            to={`/company/${company.id}/contacts`}
          >
            Contacts
          </Link>

          <Link
            className="nav-link"
            to={`/company/${company.id}/settings`}
          >
            Company settings
          </Link>
        </nav>

        <div className="user-actions">
          <Link className="nav-link" to="/account">
            My profile
          </Link>

          <Link className="text-button" to="/companies">
            Switch company
          </Link>

          <button
            className="text-button"
            onClick={() => void signOut()}
          >
            Sign out
          </button>
        </div>
      </header>

      <section className="dashboard-content">

        {/* Page heading */}
        <div className="page-heading">
          <div>
            <p className="eyebrow">COMPANY DASHBOARD</p>

            <h1>{company.company_name}</h1>

            <p className="muted">
              A snapshot of your business activity and inventory.
            </p>
          </div>

          <Link
            className="button secondary"
            to={`/company/${company.id}/settings`}
          >
            Manage company
          </Link>
        </div>

        {/* Loading */}
        {dashboard.isPending && (
          <div className="panel loading-panel">
            Loading your dashboard…
          </div>
        )}

        {/* Error */}
        {dashboard.isError && (
          <div className="alert error" role="alert">
            {dashboard.error.message}

            <button
              className="text-button"
              onClick={() => void dashboard.refetch()}
            >
              Try again
            </button>
          </div>
        )}

        {data && (
          <>

            {/* Monthly overview */}
            <p className="period-label">
              {new Date(
                `${data.period_start}T00:00:00`
              ).toLocaleDateString(undefined, {
                month: 'long',
                year: 'numeric',
              })}
            </p>

            <div className="metric-grid">

              <article className="metric-card">
                <span className="metric-icon green">
                  ↗
                </span>

                <p>Sales</p>

                <strong>
                  {money(data.sales, company.currency)}
                </strong>

                <small>Posted sales this month</small>
              </article>

              <article className="metric-card">
                <span className="metric-icon amber">
                  ↙
                </span>

                <p>Purchases</p>

                <strong>
                  {money(data.purchases, company.currency)}
                </strong>

                <small>Posted purchases this month</small>
              </article>

              <article className="metric-card">
                <span className="metric-icon rose">
                  −
                </span>

                <p>Expenses</p>

                <strong>
                  {money(data.expenses, company.currency)}
                </strong>

                <small>Posted expenses this month</small>
              </article>

              <article className="metric-card">
                <span className="metric-icon blue">
                  ▦
                </span>

                <p>Active products</p>

                <strong>
                  {data.active_product_count}
                </strong>

                <small>
                  {data.product_count} total product records
                </small>
              </article>

            </div>

            {/* Inventory overview */}
            <section className="recent-panel">

              <div className="panel-heading">
                <div>
                  <h2>Inventory overview</h2>

                  <p>
                    Current stock information for this company.
                  </p>
                </div>

                <Link
                  className="nav-link"
                  to={`/company/${company.id}/inventory`}
                >
                  Manage inventory →
                </Link>
              </div>

              <div className="metric-grid">

                <article className="metric-card">
                  <span className="metric-icon blue">
                    ◫
                  </span>

                  <p>Total stock quantity</p>

                  <strong>
                    {data.total_stock_quantity.toLocaleString()}
                  </strong>

                  <small>Based on recorded stock movements</small>
                </article>

                <article className="metric-card">
                  <span className="metric-icon green">
                    ₱
                  </span>

                  <p>Inventory valuation</p>

                  <strong>
                    {money(
                      data.total_inventory_value,
                      company.currency
                    )}
                  </strong>

                  <small>Based on recorded inventory costs</small>
                </article>

                <article className="metric-card">
                  <span className="metric-icon rose">
                    !
                  </span>

                  <p>Low-stock products</p>

                  <strong>
                    {data.low_stock_product_count}
                  </strong>

                  <small>Products at or below reorder level</small>
                </article>

                <article className="metric-card">
                  <span className="metric-icon amber">
                    ✓
                  </span>

                  <p>Active accounts</p>

                  <strong>
                    {data.active_account_count}
                  </strong>

                  <small>In your chart of accounts</small>
                </article>

              </div>

            </section>

            {/* Low stock products */}
            <section className="panel recent-panel">

              <div className="panel-heading">
                <div>
                  <h2>Low-stock alerts</h2>

                  <p>
                    Products that need inventory replenishment.
                  </p>
                </div>

                <span className="count-pill">
                  {data.low_stock_product_count} products
                </span>
              </div>

              {data.low_stock_products.length > 0 ? (

                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Product</th>
                        <th>SKU</th>
                        <th className="align-right">
                          Stock on hand
                        </th>
                        <th className="align-right">
                          Reorder level
                        </th>
                      </tr>
                    </thead>

                    <tbody>
                      {data.low_stock_products.map(product => (
                        <tr key={product.id}>
                          <td className="transaction-name">
                            {product.name}
                          </td>

                          <td>
                            {product.sku ?? '—'}
                          </td>

                          <td className="align-right">
                            {product.stock_quantity.toLocaleString()}
                          </td>

                          <td className="align-right">
                            {product.reorder_level.toLocaleString()}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

              ) : (

                <div className="empty-state">
                  <span className="empty-symbol">✓</span>

                  <h3>No low-stock products</h3>

                  <p>
                    Your products are currently above their
                    reorder levels.
                  </p>
                </div>

              )}

            </section>

            {/* Recent transactions */}
            <section className="panel recent-panel">

              <div className="panel-heading">
                <div>
                  <h2>Recent transactions</h2>

                  <p>
                    Latest posted business activities this month.
                  </p>
                </div>

                <span className="count-pill">
                  {data.transaction_count} this month
                </span>
              </div>

              {data.recent_transactions.length > 0 ? (

                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Transaction</th>
                        <th>Type</th>
                        <th>Date</th>
                        <th className="align-right">
                          Amount
                        </th>
                        <th>Status</th>
                      </tr>
                    </thead>

                    <tbody>
                      {data.recent_transactions.map(transaction => (
                        <tr key={transaction.id}>

                          <td className="transaction-name">
                            {transaction.transaction_number}
                          </td>

                          <td className="capitalize">
                            {transaction.transaction_type}
                          </td>

                          <td>
                            {shortDate(
                              transaction.transaction_date
                            )}
                          </td>

                          <td className="align-right amount">
                            {money(
                              Number(transaction.total_amount),
                              company.currency
                            )}
                          </td>

                          <td>
                            <span className="status-pill">
                              {transaction.status}
                            </span>
                          </td>

                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

              ) : (

                <div className="empty-state">
                  <span className="empty-symbol">↗</span>

                  <h3>No posted transactions yet</h3>

                  <p>
                    Your sales, purchases, and expenses will
                    appear here once they are posted.
                  </p>
                </div>

              )}

            </section>

          </>
        )}

      </section>
    </main>
  )
}