export interface CapacitorUIKitPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
