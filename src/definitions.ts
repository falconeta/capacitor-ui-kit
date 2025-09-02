import type { Plugin } from '@capacitor/core';

export interface TabBarItem {
  title: string;
  tag: number;
  image?: string;
  imageSelected?: string;
}

export interface TabBarOptions {
  selectedTag: number;
  tintColor: string;
  fontColor: string;
  fontSize: number;
  unselectedFontSize: number;
  unselectedFontColor: string;
  unselectedItemTintColor: string;
  imageBasePath?: string;
}

export interface CreateTabBar {
  items: TabBarItem[];
  options: TabBarOptions;
}

export interface CapacitorUIKitPlugin extends Plugin {
  createTabBar(options: CreateTabBar): Promise<void>;
  showTabBar(): Promise<void>;
  hideTabBar(): Promise<void>;
}
