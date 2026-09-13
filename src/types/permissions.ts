export type PermissionDescriptor = {
  id: string;
  title: string;
  description: string;
  icon: string;
  iconColor: string;
  required: boolean;
  check: () => Promise<boolean>;
  request: () => Promise<boolean>;
};
