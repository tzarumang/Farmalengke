import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { OrderLineResponse } from '@/features/orders/components/OrderLineResponse';
import { listOwnOrders } from '@/features/orders/data';
import { orderLineStatusLabels, orderStatusLabels } from '@/features/orders/schema';
import { formatPeso } from '@/features/pricing/schema';
import { getVerifiedUserId } from '@/features/profile/data';

import styles from './orders.module.css';

export const metadata: Metadata = { title: 'Orders — Farmalengke' };

export default async function OrdersPage() {
  const userId = await getVerifiedUserId();
  if (!userId) redirect('/login');

  const orders = await listOwnOrders();

  if (orders.length === 0) {
    return (
      <>
        <h1>Orders</h1>
        <EmptyState title="No orders yet">
          Orders appear here once a buyer places one against your produce, or once
          you place one yourself.
        </EmptyState>
      </>
    );
  }

  return (
    <>
      <h1>Orders</h1>

      <ul className={styles.list}>
        {orders.map((order) => {
          const deadline = new Date(order.confirmationDeadline);

          return (
            <li key={order.id} className={styles.card}>
              <div className={styles.head}>
                <h2 className={styles.title}>
                  Delivery {order.deliveryDate}
                </h2>
                <span className={styles.status} data-status={order.status}>
                  {orderStatusLabels[order.status]}
                </span>
              </div>

              <p className={styles.total}>{formatPeso(order.totalPrice)}</p>

              <p className={styles.meta}>
                To {order.deliveryBarangay}, {order.deliveryCity}, {order.deliveryProvince}
              </p>

              {order.status === 'pending' && !order.isPastDeadline ? (
                <p className={styles.meta}>
                  Answers needed by {deadline.toLocaleString('en-PH')}
                </p>
              ) : null}

              <ul className={styles.lines}>
                {order.lines.map((line) => (
                  <li key={line.id} className={styles.line}>
                    <div className={styles.lineHead}>
                      <span className={styles.lineName}>
                        {line.commodityNameFil}
                        <span className={styles.secondary}> · {line.commodityNameEn}</span>
                      </span>
                      <span className={styles.lineStatus} data-status={line.status}>
                        {orderLineStatusLabels[line.status]}
                      </span>
                    </div>

                    <p className={styles.lineDetail}>
                      {line.quantityKg} kg at {formatPeso(line.pricePerKg)}/kg ={' '}
                      <strong>{formatPeso(line.lineTotal)}</strong>
                    </p>

                    {/* Only the farmer on the line sees the buttons; the database
                        refuses anyone else, so this is presentation, not access
                        control. */}
                    {line.status === 'pending' && !order.isPastDeadline ? (
                      <OrderLineResponse
                        lineId={line.id}
                        total={formatPeso(line.lineTotal)}
                      />
                    ) : null}
                  </li>
                ))}
              </ul>
            </li>
          );
        })}
      </ul>
    </>
  );
}
