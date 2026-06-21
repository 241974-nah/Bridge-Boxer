import pygame
import sys
import random
import math

# ============================================================
# SYSTEM CONSTANTS & SETUP
# ============================================================
SCREEN_WIDTH = 900
SCREEN_HEIGHT = 650
FPS = 60

# Fixed Row Geometry Heights (Strictly alternating)
Y_BRIDGE    = 80   # Player walkway
Y_CAR_LANE1 = 200  # Car Lane 1
Y_PED_LANE1 = 300  # Pedestrian Walkway 1
Y_CAR_LANE2 = 410  # Car Lane 2
Y_PED_LANE2 = 510  # Pedestrian Walkway 2

# Colors
COLOR_BG       = (15, 18, 22)
COLOR_BRIDGE   = (60, 70, 85)
COLOR_ROAD     = (30, 33, 40)
COLOR_SIDEWALK = (45, 50, 58)
COLOR_PLAYER   = (0, 210, 255)
COLOR_BOX      = (255, 160, 0)
COLOR_CAR      = (255, 30, 70)
COLOR_PED      = (0, 255, 120)
COLOR_WRECK    = (85, 90, 100)
COLOR_TEXT     = (240, 245, 250)
COLOR_AI_LINE  = (0, 255, 255)

# ============================================================
# AI METHOD 1: DYNAMIC VEHICLE AGENTS
# ============================================================
class IntelligentCar:
    def __init__(self, y, direction, mode="DECISION_TREE"):
        self.width, self.height = 75, 32
        self.direction = direction  # -1 = Left, 1 = Right
        self.base_speed = 3.0
        self.current_speed = self.base_speed
        self.x = random.randint(100, SCREEN_WIDTH - 100)
        self.y = y
        self.is_wrecked = False
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)
        self.ai_mode = mode
        self.ai_state = "CRUISE"  

    def process_ai(self, active_box, player_x):
        if self.is_wrecked:
            self.ai_state = "DEAD"
            return

        # LEVEL 3 METHOD: Predictive Heuristic Proactive Evasion
        if self.ai_mode == "HEURISTIC_NET":
            if abs(player_x - self.rect.centerx) < 85:
                self.ai_state = "PREDICT DROP"
                self.current_speed = self.base_speed * 2.2 if self.direction == 1 else self.base_speed * 0.2
                return

        # LEVEL 1/2 METHOD: Reactive Decision Tree Logic
        if active_box is None or abs(active_box.rect.centerx - self.rect.centerx) > 140:
            self.ai_state = "CRUISE"
            self.current_speed = self.base_speed
            return

        box_dist_y = self.rect.centery - active_box.y
        if box_dist_y <= 0:
            self.ai_state = "CRUISE"
            self.current_speed = self.base_speed
            return
            
        time_to_impact = box_dist_y / max(0.5, active_box.velocity_y)
        predicted_car_x = self.rect.centerx + (self.base_speed * self.direction * time_to_impact)

        if abs(active_box.rect.centerx - predicted_car_x) < 50:
            if (self.direction == 1 and active_box.rect.centerx > self.rect.centerx) or \
               (self.direction == -1 and active_box.rect.centerx < self.rect.centerx):
                self.ai_state = "EVADE: BRAKE"
                self.current_speed = 0.4
            else:
                self.ai_state = "EVADE: NITRO"
                self.current_speed = self.base_speed * 2.5
        else:
            self.ai_state = "CRUISE"
            self.current_speed = self.base_speed

    def update(self, active_box, player_x):
        if not self.is_wrecked:
            self.process_ai(active_box, player_x)
            self.x += self.current_speed * self.direction
            if self.direction == 1 and self.x > SCREEN_WIDTH: self.x = -self.width
            elif self.direction == -1 and self.x < -self.width: self.x = SCREEN_WIDTH
            self.rect.x = self.x

    def draw(self, surface, font):
        color = COLOR_WRECK if self.is_wrecked else COLOR_CAR
        pygame.draw.rect(surface, color, self.rect, border_radius=6)
        if not self.is_wrecked:
            lbl = font.render(self.ai_state, True, (255, 255, 0) if "EVADE" in self.ai_state else (150, 160, 170))
            surface.blit(lbl, (self.rect.x, self.rect.y - 18))

# ============================================================
# AI METHOD 2: INTELLIGENT PEDESTRIAN / SENTRY AGENTS
# ============================================================
class SentryInterceptor:
    def __init__(self, y, base_x):
        self.radius = 12
        self.x, self.y = base_x, y
        self.base_x = base_x
        self.speed = 4.0
        self.patrol_dir = 1
        self.rect = pygame.Rect(self.x - self.radius, self.y - self.radius, self.radius * 2, self.radius * 2)
        self.ai_state = "PATROL"
        self.laser_target = None

    def update(self, active_box, is_level_2_or_3):
        # LEVEL 1 BEHAVIOR: Simple horizontal patrol loop
        if not is_level_2_or_3:
            self.ai_state = "PATROL"
            self.laser_target = None
            self.x += (self.speed * 0.5) * self.patrol_dir
            if abs(self.x - self.base_x) > 120: 
                self.patrol_dir *= -1
            self.rect.x = self.x - self.radius
            return

        # LEVEL 2 & 3 BEHAVIOR: Heuristic Target Interception Tracking
        if active_box is None:
            self.ai_state = "STANDBY"
            self.laser_target = None
            if self.x < self.base_x: self.x += self.speed * 0.5
            elif self.x > self.base_x: self.x -= self.speed * 0.5
        else:
            self.ai_state = "LOCK-ON"
            self.laser_target = (active_box.rect.centerx, active_box.y)
            if self.x < active_box.rect.centerx: self.x += self.speed
            elif self.x > active_box.rect.centerx: self.x -= self.speed

        self.rect.x = self.x - self.radius

    def draw(self, surface, font):
        pygame.draw.circle(surface, COLOR_PED, (int(self.x), int(self.y)), self.radius)
        pygame.draw.circle(surface, (15, 45, 25), (int(self.x), int(self.y)), self.radius - 4)
        if self.laser_target:
            pygame.draw.line(surface, COLOR_AI_LINE, (int(self.x), int(self.y)), self.laser_target, 1)
        lbl = font.render(self.ai_state, True, (0, 255, 150) if self.laser_target else (140, 150, 160))
        surface.blit(lbl, (self.x - self.radius, self.y - 22))

# ============================================================
# PROJECTILE LOGIC
# ============================================================
class SupplyBox:
    def __init__(self, x, y):
        self.width, self.height = 24, 24
        self.x = x - self.width // 2
        self.y = y
        self.gravity = 0.35
        self.velocity_y = 1.0
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)

    def update(self):
        self.velocity_y += self.gravity
        self.y += self.velocity_y
        self.rect.y = self.y

    def draw(self, surface):
        pygame.draw.rect(surface, COLOR_BOX, self.rect, border_radius=4)
        pygame.draw.line(surface, (80, 40, 0), (self.rect.left, self.rect.top), (self.rect.right, self.rect.bottom), 2)

# ============================================================
# CORE ENGINE CORE
# ============================================================
class AI_GameEngine:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("Bridge Bomber: AI Multi-Level System")
        self.clock = pygame.time.Clock()
        
        self.font_hud = pygame.font.SysFont("Arial", 18, bold=True)
        self.font_ai = pygame.font.SysFont("Courier New", 11, bold=True)
        self.font_title = pygame.font.SysFont("Impact", 44)
        
        self.state = "MENU" 
        self.level = 1
        self.auto_pilot = False 
        self.vehicles = []
        self.interceptors = []
        self.reset_game_state()

    def reset_game_state(self):
        self.score = 0
        self.player_x = SCREEN_WIDTH // 2
        self.player_y = Y_BRIDGE + 15
        self.player_speed = 6
        self.has_box = True
        self.active_box = None
        
        self.vehicles.clear()
        self.interceptors.clear()

        car_mode = "DECISION_TREE" if self.level < 3 else "HEURISTIC_NET"

        # Strictly ordered alternating rows configuration
        self.vehicles.append(IntelligentCar(Y_CAR_LANE1, -1, car_mode)) 
        self.vehicles.append(IntelligentCar(Y_CAR_LANE1, -1, car_mode))
        self.interceptors.append(SentryInterceptor(Y_PED_LANE1, 300)) 
        self.vehicles.append(IntelligentCar(Y_CAR_LANE2, 1, car_mode))  
        self.vehicles.append(IntelligentCar(Y_CAR_LANE2, 1, car_mode))
        self.interceptors.append(SentryInterceptor(Y_PED_LANE2, 600)) 

    def run(self):
        while True:
            self.handle_events()
            self.update_logic()
            self.render_graphics()
            self.clock.tick(FPS)

    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if self.state == "MENU":
                    if event.key in [pygame.K_1, pygame.K_2, pygame.K_3]:
                        self.level = int(event.unicode)
                        self.state = "PLAYING"
                        self.reset_game_state()
                    elif event.key == pygame.K_q:
                        pygame.quit()
                        sys.exit()
                elif self.state == "PLAYING":
                    if event.key == pygame.K_SPACE and self.has_box and not self.active_box and not self.auto_pilot:
                        self.active_box = SupplyBox(self.player_x, self.player_y + 15)
                        self.has_box = False
                    elif event.key == pygame.K_m:
                        self.auto_pilot = not self.auto_pilot
                    elif event.key == pygame.K_q:
                        self.state = "MENU"
                elif self.state == "GAME_OVER":
                    if event.key == pygame.K_SPACE:
                        self.state = "PLAYING"
                        self.reset_game_state()
                    elif event.key == pygame.K_q:
                        self.state = "MENU"

    def update_logic(self):
        if self.state != "PLAYING": return

        # Greedy Search Autopilot
        if self.auto_pilot:
            if not self.has_box and not self.active_box:
                target_ammo_x = 45 if self.player_x < SCREEN_WIDTH // 2 else SCREEN_WIDTH - 45
                self.player_x += self.player_speed if self.player_x < target_ammo_x else -self.player_speed
            else:
                live_targets = [v for v in self.vehicles if not v.is_wrecked]
                if live_targets:
                    nearest_car = min(live_targets, key=lambda c: abs(c.rect.centerx - self.player_x))
                    lead = (22 * nearest_car.current_speed * nearest_car.direction) / nearest_car.base_speed
                    target_x = nearest_car.rect.centerx + lead
                    if abs(self.player_x - target_x) > 10:
                        self.player_x += self.player_speed if self.player_x < target_x else -self.player_speed
                    elif self.has_box and not self.active_box:
                        self.active_box = SupplyBox(self.player_x, self.player_y + 15)
                        self.has_box = False
        else:
            keys = pygame.key.get_pressed()
            if keys[pygame.K_a] or keys[pygame.K_LEFT]: self.player_x -= self.player_speed
            if keys[pygame.K_d] or keys[pygame.K_RIGHT]: self.player_x += self.player_speed

        self.player_x = max(40, min(SCREEN_WIDTH - 40, self.player_x))

        if not self.has_box and not self.active_box and (self.player_x <= 55 or self.player_x >= SCREEN_WIDTH - 55):
            self.has_box = True

        for vehicle in self.vehicles: vehicle.update(self.active_box, self.player_x)
        for sentry in self.interceptors: sentry.update(self.active_box, self.level >= 2)

        if self.active_box:
            self.active_box.update()
            box_rect = self.active_box.rect

            # Unified Collision Matrix Handler
            for sentry in self.interceptors:
                if box_rect.colliderect(sentry.rect):
                    if self.level == 1:
                        self.score -= 10  # Penalty for hitting civilian pedestrian
                    else:
                        self.score -= 15  # Penalty for letting a drone intercept your payload
                    self.active_box = None
                    return

            for vehicle in self.vehicles:
                if not vehicle.is_wrecked and box_rect.colliderect(vehicle.rect):
                    vehicle.is_wrecked = True
                    self.score += 5
                    self.active_box = None
                    break

            if self.active_box and self.active_box.y > SCREEN_HEIGHT - 60:
                self.active_box = None

        if all(v.is_wrecked for v in self.vehicles):
            self.state = "GAME_OVER"

    def render_graphics(self):
        self.screen.fill(COLOR_BG)

        if self.state == "MENU":
            t_surf = self.font_title.render("BRIDGE BOMBER: METRIC AI ENGINE", True, COLOR_PLAYER)
            self.screen.blit(t_surf, (SCREEN_WIDTH // 2 - t_surf.get_width() // 2, 110))
            o1 = self.font_hud.render("Press [1] Level 1: Rule-Based Decision Tree Vehicle Agents", True, COLOR_TEXT)
            o2 = self.font_hud.render("Press [2] Level 2: Intelligent Heuristic Sentry Interceptors", True, COLOR_TEXT)
            o3 = self.font_hud.render("Press [3] Level 3: Dual Congestion Proactive Evasion Matrix", True, COLOR_TEXT)
            self.screen.blit(o1, (SCREEN_WIDTH // 2 - o1.get_width() // 2, 250))
            self.screen.blit(o2, (SCREEN_WIDTH // 2 - o2.get_width() // 2, 305))
            self.screen.blit(o3, (SCREEN_WIDTH // 2 - o3.get_width() // 2, 360))

        elif self.state in ["PLAYING", "GAME_OVER"]:
            # Roads
            pygame.draw.rect(self.screen, COLOR_BRIDGE, (0, Y_BRIDGE, SCREEN_WIDTH, 40))
            pygame.draw.rect(self.screen, COLOR_ROAD, (0, Y_CAR_LANE1 - 5, SCREEN_WIDTH, 60))
            pygame.draw.rect(self.screen, COLOR_SIDEWALK, (0, Y_PED_LANE1 - 15, SCREEN_WIDTH, 40))
            pygame.draw.rect(self.screen, COLOR_ROAD, (0, Y_CAR_LANE2 - 5, SCREEN_WIDTH, 60))
            pygame.draw.rect(self.screen, COLOR_SIDEWALK, (0, Y_PED_LANE2 - 15, SCREEN_WIDTH, 40))
            pygame.draw.rect(self.screen, (22, 25, 30), (0, SCREEN_HEIGHT - 50, SCREEN_WIDTH, 50))

            pygame.draw.rect(self.screen, COLOR_BOX, (15, Y_BRIDGE + 8, 24, 24), border_radius=3)
            pygame.draw.rect(self.screen, COLOR_BOX, (SCREEN_WIDTH - 39, Y_BRIDGE + 8, 24, 24), border_radius=3)

            for vehicle in self.vehicles: vehicle.draw(self.screen, self.font_ai)
            for sentry in self.interceptors: sentry.draw(self.screen, self.font_ai)
            if self.active_box: self.active_box.draw(self.screen)

            # Player
            pygame.draw.circle(self.screen, COLOR_PLAYER, (self.player_x, self.player_y), 16)
            if self.has_box:
                pygame.draw.rect(self.screen, COLOR_BOX, (self.player_x - 8, self.player_y - 8, 16, 16), border_radius=2)

            # HUD
            mode = "AUTOPILOT ACTIVE" if self.auto_pilot else "MANUAL KEYS INPUT"
            hud = self.font_hud.render(f"SCORE: {self.score}  |  LEVEL: {self.level}  |  {mode}", True, COLOR_TEXT)
            self.screen.blit(hud, (20, 25))

            if self.state == "GAME_OVER":
                veil = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
                veil.fill((0, 0, 0, 210))
                self.screen.blit(veil, (0, 0))
                w_txt = self.font_title.render("AI LEVEL EVALUATION SUCCESSFUL", True, COLOR_PED)
                s_txt = self.font_hud.render(f"TOTAL SCORE: {self.score}", True, COLOR_TEXT)
                r_txt = self.font_hud.render("Press [SPACEBAR] to Play Again  |  Press [Q] to Exit to Menu", True, COLOR_PLAYER)
                self.screen.blit(w_txt, (SCREEN_WIDTH // 2 - w_txt.get_width() // 2, SCREEN_HEIGHT // 2 - 50))
                self.screen.blit(s_txt, (SCREEN_WIDTH // 2 - s_txt.get_width() // 2, SCREEN_HEIGHT // 2 + 10))
                self.screen.blit(r_txt, (SCREEN_WIDTH // 2 - r_txt.get_width() // 2, SCREEN_HEIGHT // 2 + 70))

        pygame.draw.rect(self.screen, (255, 255, 255), (0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), width=2)
        pygame.display.flip()

if __name__ == "__main__":
    game = AI_GameEngine()
    game.run()