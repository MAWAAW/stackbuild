#!/bin/bash

# Générateur de frontend Angular avec authentification JWT

generate_frontend() {
    local project_dir=$1
    local project_name=$2
    local backend_type=$3
    
    local frontend_dir="$project_dir/frontend"
    mkdir -p "$frontend_dir"
    
    print_info "  Création de la structure Angular..."
    
    # Créer la structure Angular
    create_angular_structure "$frontend_dir"
    
    # Générer package.json
    generate_package_json "$frontend_dir" "$project_name"
    
    # Générer angular.json
    generate_angular_json "$frontend_dir" "$project_name"
    
    # Générer tsconfig
    generate_tsconfig "$frontend_dir"
    
    # Générer les composants
    generate_angular_components "$frontend_dir"
    
    # Générer les services
    generate_angular_services "$frontend_dir"
    
    # Générer Dockerfile
    generate_angular_dockerfile "$frontend_dir"
    
    # Générer netlify.toml
    generate_netlify_config "$frontend_dir"
    
    # Générer .env.example
    generate_frontend_env "$frontend_dir"
    
    print_success "  Frontend Angular généré"
}

create_angular_structure() {
    local frontend_dir=$1
    
    mkdir -p "$frontend_dir/src"/{app,assets,environments}
    mkdir -p "$frontend_dir/src/app"/{components,services,guards,interceptors,models}
    mkdir -p "$frontend_dir/src/app/components"/{login,register,home,dashboard}
}

generate_package_json() {
    local frontend_dir=$1
    local project_name=$2
    
    cat > "$frontend_dir/package.json" << EOF
{
  "name": "$project_name-frontend",
  "version": "1.0.0",
  "scripts": {
    "ng": "ng",
    "start": "ng serve",
    "build": "ng build",
    "watch": "ng build --watch --configuration development",
    "test": "ng test",
    "lint": "ng lint"
  },
  "private": true,
  "dependencies": {
    "@angular/animations": "^17.0.0",
    "@angular/common": "^17.0.0",
    "@angular/compiler": "^17.0.0",
    "@angular/core": "^17.0.0",
    "@angular/forms": "^17.0.0",
    "@angular/platform-browser": "^17.0.0",
    "@angular/platform-browser-dynamic": "^17.0.0",
    "@angular/router": "^17.0.0",
    "rxjs": "~7.8.0",
    "tslib": "^2.3.0",
    "zone.js": "~0.14.2"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^17.0.0",
    "@angular/cli": "^17.0.0",
    "@angular/compiler-cli": "^17.0.0",
    "@types/jasmine": "~5.1.0",
    "jasmine-core": "~5.1.0",
    "karma": "~6.4.0",
    "karma-chrome-launcher": "~3.2.0",
    "karma-coverage": "~2.2.0",
    "karma-jasmine": "~5.1.0",
    "karma-jasmine-html-reporter": "~2.1.0",
    "typescript": "~5.2.2"
  }
}
EOF
}

generate_angular_json() {
    local frontend_dir=$1
    local project_name=$2
    
    cat > "$frontend_dir/angular.json" << EOF
{
  "\$schema": "./node_modules/@angular/cli/lib/config/schema.json",
  "version": 1,
  "newProjectRoot": "projects",
  "projects": {
    "$project_name": {
      "projectType": "application",
      "schematics": {},
      "root": "",
      "sourceRoot": "src",
      "prefix": "app",
      "architect": {
        "build": {
          "builder": "@angular-devkit/build-angular:browser",
          "options": {
            "outputPath": "dist/$project_name",
            "index": "src/index.html",
            "main": "src/main.ts",
            "polyfills": ["zone.js"],
            "tsConfig": "tsconfig.app.json",
            "assets": ["src/favicon.ico", "src/assets"],
            "styles": ["src/styles.css"],
            "scripts": []
          },
          "configurations": {
            "production": {
              "budgets": [
                {
                  "type": "initial",
                  "maximumWarning": "500kb",
                  "maximumError": "1mb"
                }
              ],
              "outputHashing": "all"
            },
            "development": {
              "buildOptimizer": false,
              "optimization": false,
              "vendorChunk": true,
              "extractLicenses": false,
              "sourceMap": true,
              "namedChunks": true
            }
          },
          "defaultConfiguration": "production"
        },
        "serve": {
          "builder": "@angular-devkit/build-angular:dev-server",
          "configurations": {
            "production": {
              "buildTarget": "$project_name:build:production"
            },
            "development": {
              "buildTarget": "$project_name:build:development"
            }
          },
          "defaultConfiguration": "development"
        }
      }
    }
  }
}
EOF
}

generate_tsconfig() {
    local frontend_dir=$1
    
    cat > "$frontend_dir/tsconfig.json" << 'EOF'
{
  "compileOnSave": false,
  "compilerOptions": {
    "outDir": "./dist/out-tsc",
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "sourceMap": true,
    "declaration": false,
    "downlevelIteration": true,
    "experimentalDecorators": true,
    "moduleResolution": "node",
    "importHelpers": true,
    "target": "ES2022",
    "module": "ES2022",
    "useDefineForClassFields": false,
    "lib": ["ES2022", "dom"]
  },
  "angularCompilerOptions": {
    "enableI18nLegacyMessageIdFormat": false,
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "strictTemplates": true
  }
}
EOF

    cat > "$frontend_dir/tsconfig.app.json" << 'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/app",
    "types": []
  },
  "files": ["src/main.ts"],
  "include": ["src/**/*.d.ts"]
}
EOF
}

generate_angular_components() {
    local frontend_dir=$1
    
    # App Component
    cat > "$frontend_dir/src/app/app.component.ts" << 'EOF'
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: `
    <div class="app-container">
      <router-outlet></router-outlet>
    </div>
  `,
  styles: [`
    .app-container {
      min-height: 100vh;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
  `]
})
export class AppComponent {
  title = 'frontend';
}
EOF

    # Login Component
    cat > "$frontend_dir/src/app/components/login/login.component.ts" << 'EOF'
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="login-container">
      <div class="login-card">
        <h2>Login</h2>
        <form (ngSubmit)="onSubmit()">
          <div class="form-group">
            <label>Email</label>
            <input 
              type="email" 
              [(ngModel)]="credentials.email" 
              name="email"
              required>
          </div>
          <div class="form-group">
            <label>Password</label>
            <input 
              type="password" 
              [(ngModel)]="credentials.password" 
              name="password"
              required>
          </div>
          <button type="submit" [disabled]="loading">
            {{ loading ? 'Loading...' : 'Login' }}
          </button>
          <p class="error" *ngIf="error">{{ error }}</p>
        </form>
        <p class="register-link">
          Don't have an account? <a routerLink="/register">Register</a>
        </p>
      </div>
    </div>
  `,
  styles: [`
    .login-container {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
    }
    .login-card {
      background: white;
      padding: 40px;
      border-radius: 10px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.1);
      width: 100%;
      max-width: 400px;
    }
    h2 {
      margin-bottom: 30px;
      color: #333;
      text-align: center;
    }
    .form-group {
      margin-bottom: 20px;
    }
    label {
      display: block;
      margin-bottom: 5px;
      color: #666;
      font-weight: 500;
    }
    input {
      width: 100%;
      padding: 12px;
      border: 1px solid #ddd;
      border-radius: 5px;
      font-size: 14px;
    }
    button {
      width: 100%;
      padding: 12px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      border-radius: 5px;
      font-size: 16px;
      cursor: pointer;
      transition: opacity 0.3s;
    }
    button:hover:not(:disabled) {
      opacity: 0.9;
    }
    button:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
    .error {
      color: #e74c3c;
      margin-top: 10px;
      text-align: center;
    }
    .register-link {
      text-align: center;
      margin-top: 20px;
      color: #666;
    }
    .register-link a {
      color: #667eea;
      text-decoration: none;
      font-weight: 600;
    }
  `]
})
export class LoginComponent {
  credentials = { email: '', password: '' };
  loading = false;
  error = '';

  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  onSubmit() {
    this.loading = true;
    this.error = '';

    this.authService.login(this.credentials).subscribe({
      next: () => {
        this.router.navigate(['/dashboard']);
      },
      error: (err) => {
        this.error = err.error?.message || 'Login failed';
        this.loading = false;
      }
    });
  }
}
EOF

    # Main.ts
    cat > "$frontend_dir/src/main.ts" << 'EOF'
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { AppComponent } from './app/app.component';
import { authInterceptor } from './app/interceptors/auth.interceptor';
import { routes } from './app/app.routes';

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor]))
  ]
}).catch(err => console.error(err));
EOF
}

generate_angular_services() {
    local frontend_dir=$1
    
    # Auth Service
    cat > "$frontend_dir/src/app/services/auth.service.ts" << 'EOF'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';

interface LoginResponse {
  token: string;
  user: any;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl;
  private tokenSubject = new BehaviorSubject<string | null>(this.getToken());
  
  constructor(private http: HttpClient) {}

  login(credentials: any): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.apiUrl}/auth/login`, credentials)
      .pipe(tap(response => this.setToken(response.token)));
  }

  register(userData: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/auth/register`, userData);
  }

  logout() {
    localStorage.removeItem('token');
    this.tokenSubject.next(null);
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  private setToken(token: string) {
    localStorage.setItem('token', token);
    this.tokenSubject.next(token);
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }
}
EOF

    # Auth Interceptor
    cat > "$frontend_dir/src/app/interceptors/auth.interceptor.ts" << 'EOF'
import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('token');
  
  if (token) {
    req = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    });
  }
  
  return next(req);
};
EOF

    # Routes
    cat > "$frontend_dir/src/app/app.routes.ts" << 'EOF'
import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';

export const routes: Routes = [
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: '**', redirectTo: '/login' }
];
EOF

    # Environment
    cat > "$frontend_dir/src/environments/environment.ts" << 'EOF'
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api'
};
EOF
}

generate_angular_dockerfile() {
    local frontend_dir=$1
    
    cat > "$frontend_dir/Dockerfile" << 'EOF'
FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=build /app/dist/*/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

    cat > "$frontend_dir/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
}

generate_netlify_config() {
    local frontend_dir=$1
    
    cat > "$frontend_dir/netlify.toml" << 'EOF'
[build]
  command = "npm run build"
  publish = "dist/frontend/browser"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
EOF
}

generate_frontend_env() {
    local frontend_dir=$1
    
    cat > "$frontend_dir/.env.example" << 'EOF'
VITE_API_URL=http://localhost:8080/api
EOF
}