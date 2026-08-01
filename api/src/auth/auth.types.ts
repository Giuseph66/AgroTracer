export type AuthPrincipal = {
  actorId: string;
  organizationId: string;
  propertyId: string;
  propertyName: string;
  deviceId: string;
  subject: string;
  name: string;
  email: string | null;
  roles: string[];
  permissions: string[];
};

export type AuthConfig = {
  required: boolean;
  mode: 'dev' | 'oidc';
  issuer: string | null;
};
