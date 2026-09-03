import {
  ArrayMinSize,
  IsArray,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
} from '@nestjs/common';

import { RequirePermission } from '../auth/permission.decorator';
import { ROLE_CODES } from '../auth/policy.service';
import { AuthPrincipal } from '../auth/auth.types';
import { AdminService } from './admin.service';

class CreateUserDto {
  @IsString()
  @MinLength(2)
  name: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(4)
  password: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsIn(ROLE_CODES, { each: true })
  roles: string[];
}

class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  name?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MinLength(4)
  password?: string;

  @IsOptional()
  @IsIn(['ACTIVE', 'SUSPENDED'])
  status?: 'ACTIVE' | 'SUSPENDED';

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @IsIn(ROLE_CODES, { each: true })
  roles?: string[];
}

@Controller('admin')
@RequirePermission('users.manage')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('roles')
  roles(@Req() request: { user: AuthPrincipal }) {
    return { data: this.admin.roles(request.user) };
  }

  @Get('users')
  async users(@Req() request: { user: AuthPrincipal }) {
    return { data: await this.admin.users(request.user) };
  }

  @Post('users')
  async create(
    @Req() request: { user: AuthPrincipal },
    @Body() body: CreateUserDto,
  ) {
    return { data: await this.admin.create(request.user, body) };
  }

  @Patch('users/:userId')
  async update(
    @Req() request: { user: AuthPrincipal },
    @Param('userId', new ParseUUIDPipe()) userId: string,
    @Body() body: UpdateUserDto,
  ) {
    return { data: await this.admin.update(request.user, userId, body) };
  }
}
