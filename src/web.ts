import { WebPlugin } from '@capacitor/core';

import type { CapacitorUIKitPlugin, CreateOrSetToolbar, CreateTabBar } from './definitions';

export class CapacitorUIKitWeb extends WebPlugin implements CapacitorUIKitPlugin {
  createToolbar(options: CreateOrSetToolbar): Promise<void> {
    console.log('createToolbar', options);
    throw new Error('Method not implemented.');
  }
  setToolbarItems(options: CreateOrSetToolbar): Promise<void> {
    console.log('setToolbarItems', options);
    throw new Error('Method not implemented.');
  }
  showToolbar(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  hideToolbar(): Promise<void> {
    throw new Error('Method not implemented.');
  }
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
