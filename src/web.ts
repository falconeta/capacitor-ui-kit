import { WebPlugin } from '@capacitor/core';

import type { CapacitorUIKitPlugin, CreateOrSetToolbar, CreateTabBar } from './definitions';

export class CapacitorUIKitWeb extends WebPlugin implements CapacitorUIKitPlugin {
  createTopToolbar(options: CreateOrSetToolbar): Promise<void> {
    console.log('createTopToolbar', options);
    throw new Error('Method not implemented.');
  }
  setTopToolbarItems(options: CreateOrSetToolbar): Promise<void> {
    console.log('setTopToolbarItems', options);
    throw new Error('Method not implemented.');
  }
  showTopToolbar(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  hideTopToolbar(): Promise<void> {
    throw new Error('Method not implemented.');
  }
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
