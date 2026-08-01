import { Injectable } from '@nestjs/common';

import { AuthPrincipal } from './auth.types';

export const ROLE_CATALOG = [
  {
    code: 'OPER',
    name: 'Operador de curral',
    description: 'Rotina de campo, leitura, pesagem e manejo.',
    permissions: ['field.operate'],
  },
  {
    code: 'PROD',
    name: 'Produtor / gestor',
    description: 'Visão da propriedade, relatórios e aprovações.',
    permissions: ['field.operate', 'reports.export', 'users.read'],
  },
  {
    code: 'TECN',
    name: 'Técnico agropecuário',
    description: 'Manejo técnico nas propriedades vinculadas.',
    permissions: ['field.operate', 'health.apply'],
  },
  {
    code: 'VETE',
    name: 'Veterinário',
    description: 'Atos sanitários privativos e acompanhamento clínico.',
    permissions: ['health.private', 'health.apply', 'reports.export'],
  },
  {
    code: 'CERT',
    name: 'Certificador',
    description: 'Leitura temporária e decisões de certificação.',
    permissions: ['certification.review', 'reports.export'],
  },
  {
    code: 'TRAN',
    name: 'Transportador',
    description: 'Embarques sob custódia da transportadora.',
    permissions: ['shipment.transport'],
  },
  {
    code: 'FRIG',
    name: 'Operador de frigorífico',
    description: 'Recebimento, abate e registros da planta vinculada.',
    permissions: ['slaughter.operate', 'shipment.receive'],
  },
  {
    code: 'AUDI',
    name: 'Auditor',
    description: 'Leitura e exportação no escopo do mandato.',
    permissions: ['audit.read', 'reports.export'],
  },
  {
    code: 'ADMO',
    name: 'Administrador da organização',
    description: 'Usuários, perfis e dispositivos da própria organização.',
    permissions: ['users.read', 'users.manage', 'devices.manage'],
  },
  {
    code: 'ADMP',
    name: 'Administrador da plataforma',
    description: 'Administração da plataforma sem operar eventos de campo.',
    permissions: ['platform.manage', 'users.read', 'users.manage'],
  },
  {
    code: 'PUBL',
    name: 'Consulta pública',
    description: 'Somente visões públicas e provas resumidas.',
    permissions: ['public.read'],
  },
] as const;

export const ROLE_CODES = ROLE_CATALOG.map((role) => role.code);

@Injectable()
export class PolicyService {
  permissionsFor(roles: string[]): string[] {
    return [...new Set(
      ROLE_CATALOG
        .filter((role) => roles.includes(role.code))
        .flatMap((role) => [...role.permissions]),
    )].sort();
  }

  allows(principal: AuthPrincipal, permission: string): boolean {
    return principal.permissions.includes(permission);
  }

  roles() {
    return ROLE_CATALOG.map(({ code, name, description }) => ({
      code,
      name,
      description,
    }));
  }
}
