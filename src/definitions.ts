import type { Plugin } from '@capacitor/core';

export interface TabBarItem {
  title: string;
  tag: number;
  image?: string;
  imageSelected?: string;
}

export interface SearchBarItem {
  placeholder: string;
}

export interface TabBarOptions {
  selectedTag: number;
  fontSize: number;
  unselectedFontSize: number;
  tintColor: string;
  fontColor: string;
  unselectedFontColor: string;
  unselectedItemTintColor: string;
  fontColorDark?: string;
  unselectedFontColorDark?: string;
  tintColorDark?: string;
  unselectedItemTintColorDark?: string;
  imageBasePath?: string;
}

export interface CreateTabBar {
  items: TabBarItem[];
  options: TabBarOptions;
  searchBarItem?: SearchBarItem;
}

export interface CapacitorUIKitPlugin extends Plugin {
  createTabBar(options: CreateTabBar): Promise<void>;
  showTabBar(): Promise<void>;
  hideTabBar(): Promise<void>;
  showSearch(): Promise<void>;
  hideSearch(): Promise<void>;
}
