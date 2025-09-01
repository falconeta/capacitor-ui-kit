import { registerPlugin } from '@capacitor/core';

import type { CapacitorUIKitPlugin } from './definitions';

const CapacitorUIKit = registerPlugin<CapacitorUIKitPlugin>('CapacitorUIKit', {
  web: () => import('./web').then((m) => new m.CapacitorUIKitWeb()),
});

export * from './definitions';
export { CapacitorUIKit };
