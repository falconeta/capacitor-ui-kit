import { WebPlugin } from '@capacitor/core';

import type { CapacitorUIKitPlugin } from './definitions';

export class CapacitorUIKitWeb extends WebPlugin implements CapacitorUIKitPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
