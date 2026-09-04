import type { Metadata } from 'next';
import { redirect } from 'next/navigation';

import { EmptyState } from '@/components/ui/EmptyState';
import { Notice } from '@/components/ui/Notice';
import { CooperativeForm } from '@/features/cooperatives/components/CooperativeForm';
import { InvitationResponse } from '@/features/cooperatives/components/InvitationResponse';
import { InviteMember } from '@/features/cooperatives/components/InviteMember';
import { LeaveCooperative } from '@/features/cooperatives/components/LeaveCooperative';
import { listOwnCooperatives, listOwnInvitations } from '@/features/cooperatives/data';
import { membershipStatusLabels } from '@/features/cooperatives/schema';
import { getVerifiedUserId } from '@/features/profile/data';
import { listRegions } from '@/features/reference/data';

import styles from './cooperative.module.css';

export const metadata: Metadata = { title: 'Your group — Farmalengke' };

export default async function CooperativePage() {
  const userId = await getVerifiedUserId();
  if (!userId) redirect('/login');

  const [cooperatives, invitations, regions] = await Promise.all([
    listOwnCooperatives(),
    listOwnInvitations(),
    listRegions(),
  ]);

  return (
    <>
      <h1>Your group</h1>

      {invitations.length > 0 ? (
        <section className={styles.section}>
          <h2>Invitations</h2>
          {invitations.map((invitation) => (
            <div key={invitation.membershipId} className={styles.card}>
              <InvitationResponse
                membershipId={invitation.membershipId}
                cooperativeName={invitation.cooperativeName}
              />
            </div>
          ))}
        </section>
      ) : null}

      {cooperatives.length === 0 ? (
        <>
          {invitations.length === 0 ? (
            <EmptyState title="You are not in a group yet">
              Selling together lets a group reach volumes none of you could alone.
              You can register one, or wait to be invited to one.
            </EmptyState>
          ) : null}

          <h2>Register a group</h2>
          <p>
            You will be its officer: the person the group is answerable through,
            and the one who offers its produce to buyers.
          </p>
          <CooperativeForm regions={regions} />
        </>
      ) : (
        cooperatives.map((cooperative) => {
          const ownMembership = cooperative.members.find((m) => m.farmerId === userId);
          const activeMembers = cooperative.members.filter((m) => m.status === 'active');

          return (
            <section key={cooperative.id} className={styles.section}>
              <h2>{cooperative.name}</h2>
              <p className={styles.meta}>
                {cooperative.barangay}, {cooperative.cityMunicipality},{' '}
                {cooperative.province} · {activeMembers.length} member
                {activeMembers.length === 1 ? '' : 's'}
                {cooperative.isOfficer ? ' · you are the officer' : ''}
              </p>

              <ul className={styles.members}>
                {cooperative.members.map((member) => (
                  <li key={member.membershipId} className={styles.member}>
                    <span>
                      {member.displayName ?? member.mobileNumber}
                      {member.farmerId === cooperative.officerId ? ' (officer)' : ''}
                    </span>
                    <span className={styles.status}>
                      {membershipStatusLabels[member.status]}
                    </span>
                  </li>
                ))}
              </ul>

              {cooperative.isOfficer ? (
                <>
                  <h3>Invite a member</h3>
                  <InviteMember cooperativeId={cooperative.id} />

                  <Notice tone="info" title="Selling together">
                    When you list produce for the group, record what each member
                    brought. Every member has to be verified for their own share —
                    a group cannot sell more than its members can individually.
                  </Notice>
                </>
              ) : ownMembership?.status === 'active' ? (
                <LeaveCooperative membershipId={ownMembership.membershipId} />
              ) : null}
            </section>
          );
        })
      )}
    </>
  );
}
