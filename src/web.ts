import { WebPlugin } from '@capacitor/core';

import type { CapacitorUIKitPlugin, CreateOrSetToolbar, CreateTabBar } from './definitions';

export class CapacitorUIKitWeb extends WebPlugin implements CapacitorUIKitPlugin {
  async presentActionSheet(): Promise<{ role: string }> { throw this.unimplemented('Native action sheets require iOS'); }
  async presentDialog(): Promise<{ role: string }> { throw this.unimplemented('Native dialogs require iOS'); }
  async dismissDialog(): Promise<{ dismissed: boolean }> { throw this.unimplemented('Native dialogs require iOS'); }
  async dismissWebSheet(): Promise<void> { throw this.unimplemented('Native web sheets require iOS'); }
  async presentToast(): Promise<void> { throw this.unimplemented('Native toasts require iOS'); }
  async dismissToast(): Promise<void> { throw this.unimplemented('Native toasts require iOS'); }
  async completeWebSheetAction(): Promise<void> { throw this.unimplemented('Native web sheets require iOS'); }
  async presentWebSheet(): Promise<{ role: 'close' | 'gesture' }> { throw this.unimplemented('Native web sheets require iOS'); }
  async beginTopToolbarTransition(): Promise<{ duration: number; timing: 'native' }> { throw this.unimplemented('Native toolbar transitions require iOS'); }
  async updateTopToolbarTransition(): Promise<void> { throw this.unimplemented('Native toolbar transitions require iOS'); }
  async finishTopToolbarTransition(): Promise<void> { throw this.unimplemented('Native toolbar transitions require iOS'); }
  initialize(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  reRender(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  removeTabs(): Promise<void> {
    throw new Error('Method not implemented.');
  }
  tabBarSelected(): Promise<{ value: number | undefined; }> {
    throw new Error('Method not implemented.');
  }
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
