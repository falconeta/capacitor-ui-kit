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

export enum ToolbarItemType {
  Button = 0,
  FlexibleSpace,
  Menu,
}

export enum ToolbarMenuItemType {
  Action = 0,
  Separator,
}

export enum ToolbarButtonItemStyle {
  Plain = 0,
  Prominent,
}
export enum ToolbarMenuItemAttributes {
  KeepsMenuPresented = 0,
  Destructive,
  Disabled,
  Hidden,
}

export interface ToolbarItem<T extends ToolbarItemType> {
  type: T;
  data: ToolbarItemData[T];
}

export interface ToolbarMenuItem<T extends ToolbarMenuItemType> {
  type: T;
  data: ToolbarMenuItemData[T];
}

export interface ToolbarMenuItemData {
  [ToolbarMenuItemType.Action]: {
    identifier: string;
    attributes?: ToolbarMenuItemAttributes[];
    title?: string;
    image?: string;
  };
  [ToolbarMenuItemType.Separator]: void;
}

export interface ToolbarItemData {
  [ToolbarItemType.Button]: {
    tag: number;
    image?: string;
    title?: string;
    style?: ToolbarButtonItemStyle;
    tintColor?: string;
  };
  [ToolbarItemType.FlexibleSpace]: void;
  [ToolbarItemType.Menu]: {
    image?: string;
    title?: string;
    menuTitle?: string;
    items: ToolbarMenuItem<ToolbarMenuItemType>[];
  };
}

export interface ToolbarOptions {
  imageBasePath?: string;
}

export interface CreateOrSetToolbar {
  items: ToolbarItem<ToolbarItemType>[];
  options: ToolbarOptions;
}

export interface CapacitorUIKitPlugin extends Plugin {
  createTabBar(options: CreateTabBar): Promise<void>;
  createToolbar(options: CreateOrSetToolbar): Promise<void>;
  createTopToolbar(options: CreateOrSetToolbar): Promise<void>;
  setToolbarItems(options: CreateOrSetToolbar): Promise<void>;
  setTopToolbarItems(options: CreateOrSetToolbar): Promise<void>;
  showTabBar(): Promise<void>;
  hideTabBar(): Promise<void>;
  showSearch(): Promise<void>;
  hideSearch(): Promise<void>;
  showToolbar(): Promise<void>;
  hideToolbar(): Promise<void>;
  showTopToolbar(): Promise<void>;
  hideTopToolbar(): Promise<void>;
}
