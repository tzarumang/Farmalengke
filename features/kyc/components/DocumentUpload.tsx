'use client';

import { useActionState, useState } from 'react';

import { Button } from '@/components/ui/Button';
import { Notice } from '@/components/ui/Notice';
import { createClient } from '@/lib/supabase/client';

import { recordDocument, type KycState } from '../actions';
import {
  ACCEPTED_IMAGE_TYPES,
  MAX_DOCUMENT_BYTES,
  documentLabels,
  documentStoragePath,
  type KycDocumentType,
} from '../schema';

import styles from './DocumentUpload.module.css';

const initialState: KycState = {};

/**
 * Uploads one document straight to the private bucket, then records it.
 *
 * The file goes to storage from the browser rather than through the server: an
 * ID photo is several megabytes, and routing it through a Server Action would
 * hit the body limit and put biometric data in application logs for no benefit.
 * The storage policy pins the path to the caller's own folder, so a browser
 * cannot write anywhere else however this path is constructed.
 */
export function DocumentUpload({
  userId,
  submissionId,
  documentType,
  description,
  alreadyUploaded,
}: {
  userId: string;
  submissionId: string;
  documentType: KycDocumentType;
  description: string;
  alreadyUploaded: boolean;
}) {
  const [state, formAction] = useActionState(recordDocument, initialState);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [uploaded, setUploaded] = useState(alreadyUploaded);

  async function handleFile(file: File, submit: () => void) {
    setUploadError(null);

    if (!ACCEPTED_IMAGE_TYPES.includes(file.type as (typeof ACCEPTED_IMAGE_TYPES)[number])) {
      setUploadError('Use a JPEG, PNG or WebP photo.');
      return;
    }
    if (file.size > MAX_DOCUMENT_BYTES) {
      setUploadError('That photo is too large. Keep it under 5 MB.');
      return;
    }

    setUploading(true);
    const supabase = createClient();
    const { error } = await supabase.storage
      .from('kyc-documents')
      .upload(documentStoragePath(userId, submissionId, documentType), file, {
        upsert: true,
        contentType: file.type,
      });
    setUploading(false);

    if (error) {
      setUploadError('The upload did not finish. Check your signal and try again.');
      return;
    }

    setUploaded(true);
    submit();
  }

  return (
    <div className={styles.item}>
      <h3 className={styles.title}>{documentLabels[documentType]}</h3>
      <p className={styles.description}>{description}</p>

      {uploaded ? <Notice tone="success">Received.</Notice> : null}
      {uploadError ? <Notice tone="error">{uploadError}</Notice> : null}
      {state.error ? <Notice tone="error">{state.error}</Notice> : null}

      <form action={formAction}>
        <input type="hidden" name="submissionId" value={submissionId} />
        <input type="hidden" name="documentType" value={documentType} />

        <label className={styles.fileLabel} htmlFor={`file-${documentType}`}>
          <span className={styles.fileLabelText}>
            {uploaded ? 'Replace photo' : 'Choose photo'}
          </span>
          <input
            id={`file-${documentType}`}
            type="file"
            accept={ACCEPTED_IMAGE_TYPES.join(',')}
            capture="environment"
            className={styles.file}
            disabled={uploading}
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (!file) return;
              const form = event.target.form;
              void handleFile(file, () => form?.requestSubmit());
            }}
          />
        </label>

        {uploading ? <p className={styles.uploading}>Sending photo…</p> : null}
        <noscript>
          <Button type="submit">Save</Button>
        </noscript>
      </form>
    </div>
  );
}
