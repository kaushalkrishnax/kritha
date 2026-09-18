import { useState, useCallback } from 'react';

import { PERMISSION_DESCRIPTORS } from '@/services';

export function usePermissionsChecklist() {
  const [status, setStatus] = useState<Record<string, boolean>>({});

  const refresh = useCallback(async () => {
    const newStatus: Record<string, boolean> = {};
    for (const desc of PERMISSION_DESCRIPTORS) {
      newStatus[desc.id] = await desc.check();
    }
    setStatus(newStatus);
  }, []);

  const request = useCallback(async (id: string) => {
    const desc = PERMISSION_DESCRIPTORS.find((d) => d.id === id);
    if (!desc) return;
    const granted = await desc.request();
    if (granted) {
      setStatus((prev) => ({ ...prev, [id]: true }));
    } else {
      // Recheck anyway in case of settings intent return
      const isGranted = await desc.check();
      setStatus((prev) => ({ ...prev, [id]: isGranted }));
    }
  }, []);

  return { status, refresh, request, descriptors: PERMISSION_DESCRIPTORS };
}
