import { WebPlugin } from '@capacitor/core';

import type { CapacitorUIKitPlugin, CreateTabBar } from './definitions';

export class CapacitorUIKitWeb extends WebPlugin implements CapacitorUIKitPlugin {
  showSearch(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  hideSearch(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  showTabBar(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  hideTabBar(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  createTabBar(options: CreateTabBar): Promise<void> {
    console.log('createTabBar', options);
    throw new Error('Method not implemented.');
  }
}
