import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { IsEmail, IsString, MinLength } from 'class-validator';

import { AuthService } from './auth.service';
import { AuthPrincipal } from './auth.types';
import { Public } from './public.decorator';

class DevLoginDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(4)
  password: string;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Get('config')
  config() {
    return this.auth.config();
  }

  @Public()
  @Post('dev-login')
  devLogin(@Body() body: DevLoginDto) {
    return this.auth.devLogin(body.email, body.password);
  }

  @Get('me')
  me(@Req() request: { user?: AuthPrincipal }) {
    return { data: request.user ?? null };
  }
}
