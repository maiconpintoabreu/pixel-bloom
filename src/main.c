
#include "raylib.h"
#include "raymath.h"

#if defined(PLATFORM_WEB)
    #include <emscripten/emscripten.h>
#endif
#define MAX_WIND_PARTICLES 200
#define MAX_WATER_PARTICLES 200


const int NATIVE_WIDTH = 160; // e.g., 160x90 for a 16:9 aspect ratio
const int NATIVE_HEIGHT = 90;

const float PHYSICS_TIME            = 0.02;
const int FONT_SIZE                 = 20;
const int LINE_DURATION = 10;
const int DEHIDRATION_DAMAGE = 10;
const int TOO_MUCH_WATER_DAMAGE = 10;
const int SHIELD_RADIUS = 5;
const int DEFAULT_BAR_HEIGHT = 40;
// const int PLAYER_MAX_SHOOTS			= 100;

// Flower consts
const int FLOWER_FRAMES = 7;
const float FLOWER_FRAME_SPEED  = .3;
const float FLOWER_WATER_DRAIN_SPEED = 10;
const float FLOWER_MAX_WATER_LEVEL = 200;

// Sun consts
const int SUN_FRAMES = 8;
const float SUN_FRAME_SPEED  = .3;
const float SUN_AMOUNT = 10.0;
const float WIND_PARTICLES_CD = 1;

// Cloud consts
const int CLOUD_FRAMES = 8;
const float CLOUD_FRAME_SPEED  = .3;
const float CLOUD_AMOUNT = 5.0;
const float WATER_PARTICLES_CD = .3;

typedef struct Flower {
    float frameTimer;
    float waterLevel;
    float health;
    int currentFrame;
    bool isAlive;
    Texture2D texture;
} Flower;

typedef struct Sun {
    float frameTimer;
    int currentFrame;
    int sunAmount;
    Texture2D texture;
} Sun;

typedef struct Cloud {
    float frameTimer;
    int currentFrame;
    int rainAmount;
    Texture2D texture;
} Cloud;

typedef struct WindParticles {
    float power;
    Vector2 position;
} WindParticles;

typedef struct WaterParticles {
    float amount;
    Vector2 position;
} WaterParticles;

typedef enum GameStateType {
    StateInGame = 1,
    StateStartMenu = 2,
    StateGameOver = 3,
} GameStateType;

typedef enum DamageType {
    NoneDamage = 0,
    DehidrationDamage = 1,
    WindDamage = 2,
    DrawningDamage = 3,
} DamageType;

typedef struct Game {
    Texture2D healthTexture;
    Texture2D waterTexture;
    WindParticles windArray[MAX_WIND_PARTICLES];
    WaterParticles waterArray[MAX_WATER_PARTICLES];
    Flower flower;
    Sun sun;
    Cloud cloud;
    Vector2 shieldPosition;
	GameStateType state;
    DamageType gameOverType;
    int width;
    int height;
    float virtualRatio;
    float score;
    float highestScore;
    int windArrayAmount;
    int waterArrayAmount;
    float windParticleCD;
    float waterParticleCD;
    bool isSunUp;
    bool skipInput;
    bool isMusicPaused;
    bool isPaused;
    bool isShielding;
} Game;

static Game game = {0};

static const float menu_size_width = 200.0f;
static const float item_menu_size_height = 50.0f;
static Rectangle exitMenuRec = {0};
static Rectangle startMenuRec = {0};
static Rectangle restartMenuRec = {0};
static RenderTexture2D target = {0};


static Rectangle healthRec = {0};
static Rectangle hidrationRec = {0};

// The target's height is flipped (in the source Rectangle), due to OpenGL reasons
static Rectangle sourceRec = {0};
static Rectangle destRec = {0};

static Music music = {0};

static bool isPlaying = true;

 
int MenuButtom(Rectangle buttom, const char *buttom_text) {
    if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON) && CheckCollisionPointRec(GetMousePosition(), buttom))
    {
        game.skipInput = true;
        return true;
    }
    DrawRectangleRec(buttom, GRAY);

    DrawText(buttom_text, buttom.x + 20, buttom.y + buttom.height / 2 - 10, 20, WHITE);
    return 0;
}

void PlaceUIButtons(){
    // Add start button
    startMenuRec.x = (game.width / 2) - menu_size_width / 2;
    startMenuRec.y = (game.height / 2) - item_menu_size_height / 1.5f;
    startMenuRec.width = menu_size_width;
    startMenuRec.height = item_menu_size_height;
    // Add restart button
    restartMenuRec = startMenuRec;
    // Add exit button
    exitMenuRec.x = (game.width / 2) - menu_size_width / 2;
    exitMenuRec.y = (game.height / 2) + item_menu_size_height / 1.5f;
    exitMenuRec.width = menu_size_width;
    exitMenuRec.height = item_menu_size_height;
    
    destRec = (Rectangle){ -game.virtualRatio, -game.virtualRatio, game.width + (game.virtualRatio*2), game.height + (game.virtualRatio*2) };
}

void ResetGame() {
    game.flower.frameTimer = 0;
    game.flower.waterLevel = 120;
    game.flower.currentFrame = 0;
    game.flower.health = 100;
    game.flower.isAlive = true;
    game.cloud.currentFrame = 0;
    game.sun.currentFrame = 0;
    game.windArrayAmount = 0;
    game.waterArrayAmount = 0;
    game.windParticleCD = WIND_PARTICLES_CD;
    game.waterParticleCD = WATER_PARTICLES_CD;
    game.isSunUp = true;
    game.isShielding = false;
    game.score = 0;
    game.gameOverType = NoneDamage;
    game.skipInput = false;
    game.isPaused = false;
    
    healthRec = (Rectangle){NATIVE_WIDTH-20, NATIVE_HEIGHT-DEFAULT_BAR_HEIGHT, 4, DEFAULT_BAR_HEIGHT};
    hidrationRec = (Rectangle){NATIVE_WIDTH-10, NATIVE_HEIGHT-DEFAULT_BAR_HEIGHT, 4, DEFAULT_BAR_HEIGHT};
}
void LoadTextures() {
    game.flower.texture = LoadTexture("resources/flower.png");
    game.sun.texture = LoadTexture("resources/sun.png");
    game.cloud.texture = LoadTexture("resources/cloud.png");
    game.waterTexture = LoadTexture("resources/water.png");
    game.healthTexture = LoadTexture("resources/health.png");
}
void UnloadTextures() {
    if(target.id != 0) {
        UnloadRenderTexture(target);
    }
    if(game.flower.texture.id != 0) {
        UnloadTexture(game.flower.texture);
    }
    if(game.sun.texture.id != 0) {
        UnloadTexture(game.sun.texture);
    }
    if(game.cloud.texture.id != 0) {
        UnloadTexture(game.cloud.texture);
    }
    if(game.healthTexture.id != 0) {
        UnloadTexture(game.healthTexture);
    }
    if(game.waterTexture.id != 0) {
        UnloadTexture(game.waterTexture);
    }
}
void UpdateScreenValues() {
    if(IsWindowFullscreen()) {
        game.width = GetMonitorWidth(GetCurrentMonitor());
        game.height = GetMonitorHeight(GetCurrentMonitor());
    }else{
        game.width = GetScreenWidth();
        game.height = GetScreenHeight();
    }
    game.virtualRatio = game.height/NATIVE_HEIGHT;
}
void TakeDamage(float damage, DamageType damageType) {
    if (!game.flower.isAlive) return;
    game.flower.health =  game.flower.health - damage;
    if (game.flower.health <= 0) {
        game.flower.isAlive = false;
        game.flower.health = 0;
        if(game.score > game.highestScore) {
            game.highestScore = game.score;
        }
        game.state = StateGameOver;
        game.gameOverType = damageType;
    }
    const float healthHeight = DEFAULT_BAR_HEIGHT*game.flower.health/100;
    healthRec.y = NATIVE_HEIGHT-healthHeight;
    healthRec.height = healthHeight;
}
void TakeWater(float water) {
    if (!game.flower.isAlive) return;
    game.flower.waterLevel += water;
    const float hidrationHeight = DEFAULT_BAR_HEIGHT*game.flower.waterLevel/FLOWER_MAX_WATER_LEVEL;
    hidrationRec.y = NATIVE_HEIGHT-hidrationHeight;
    hidrationRec.height = hidrationHeight;
    if (game.flower.waterLevel > FLOWER_MAX_WATER_LEVEL) {
        TakeDamage(TOO_MUCH_WATER_DAMAGE, DrawningDamage);
        game.flower.waterLevel = FLOWER_MAX_WATER_LEVEL;
    } else {
        game.flower.health += 1;
        if(game.flower.health > 100) {
            game.flower.health = 100;
        }
        const float healthHeight = DEFAULT_BAR_HEIGHT*game.flower.health/100;
        healthRec.y = NATIVE_HEIGHT-healthHeight;
        healthRec.height = healthHeight;
    }
}

void UpdateFrame() {
    if(!isPlaying) {
        BeginDrawing();
            ClearBackground(BLACK);
            DrawText("The game is Closed", game.width/2-20, game.height/2-10, 20, WHITE);
        EndDrawing();
        return;
    }
    if(IsWindowResized()){
        PlaceUIButtons();
    }
    // Tick
    UpdateMusicStream(music);   // Update music buffer with new stream data
    if(game.state == StateInGame){
        const float delta = GetFrameTime();
        if(!game.isPaused) {
            if (IsWindowResized()) {
                if(IsWindowFullscreen()) {
                    game.width = GetMonitorWidth(GetCurrentMonitor());
                    game.height = GetMonitorHeight(GetCurrentMonitor());
                }else{
                    game.width = GetScreenWidth();
                    game.height = GetScreenHeight();
                }
                UpdateScreenValues();
            }
            SetMouseScale(1 / game.virtualRatio, 1 / game.virtualRatio);
            const Rectangle flowerButtom = (Rectangle){60, NATIVE_HEIGHT - 50, game.flower.texture.width / FLOWER_FRAMES, 50};
            const Vector2 mousePosition = GetMousePosition();
            if (IsKeyPressed(KEY_SPACE) ||
                (IsMouseButtonReleased(MOUSE_LEFT_BUTTON) && 
                CheckCollisionPointRec(mousePosition, flowerButtom))) {
                game.isSunUp = !game.isSunUp;
                game.cloud.currentFrame = 0;
                game.sun.currentFrame = 0;
                game.windArrayAmount = 0;
                game.waterArrayAmount = 0;
                game.windParticleCD = WIND_PARTICLES_CD;
                game.waterParticleCD = WATER_PARTICLES_CD;
                game.skipInput = true;
            }
            if(game.skipInput){
                game.shieldPosition = (Vector2){0};
                game.isShielding = false;
            }else{
                if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
                    game.isShielding = true;
                }
                if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON)) {
                    game.shieldPosition = (Vector2){0};
                    game.isShielding = false;
                }
            }
            if(game.isShielding) {
                game.shieldPosition = mousePosition;
            }
            game.skipInput = false;

            // Calc Score
            if(game.flower.isAlive && game.isSunUp) {
                game.score += game.flower.health/100 * delta;
            }
            SetMouseScale(1, 1);
            if (game.isSunUp) {
                game.sun.frameTimer += delta;
                if (game.sun.frameTimer >= SUN_FRAME_SPEED) {
                    game.sun.frameTimer = 0;
                    game.sun.currentFrame = GetRandomValue(0, SUN_FRAMES - 1);
                    if (game.sun.currentFrame >= SUN_FRAMES) game.sun.currentFrame = 0;
                }
            } else {
                game.cloud.frameTimer += delta;
                if (game.cloud.frameTimer >= CLOUD_FRAME_SPEED) {
                    game.cloud.frameTimer = 0;
                    game.cloud.currentFrame += 1;
                    if (game.cloud.currentFrame >= CLOUD_FRAMES) game.cloud.currentFrame = 0;
                }
            }
            if(game.flower.isAlive) {
                game.flower.frameTimer += delta;
                if (game.flower.frameTimer >= FLOWER_FRAME_SPEED) {
                    game.flower.frameTimer = 0;
                    game.flower.currentFrame += 1;
                    if (game.flower.currentFrame >= FLOWER_FRAMES) game.flower.currentFrame = 0;
                }
                if (game.flower.waterLevel != 0.0) {
                    if(game.isSunUp){
                        game.flower.waterLevel = game.flower.waterLevel - (FLOWER_WATER_DRAIN_SPEED * delta);
                        const float hidrationHeight = DEFAULT_BAR_HEIGHT*game.flower.waterLevel/FLOWER_MAX_WATER_LEVEL;
                        hidrationRec.y = NATIVE_HEIGHT-hidrationHeight;
                        hidrationRec.height = hidrationHeight;
                    }
                }else{
                    TakeDamage(DEHIDRATION_DAMAGE * delta, DehidrationDamage);
                }
                if (game.flower.waterLevel < 0.0) {
                    game.flower.waterLevel = 0.0;
                    TakeDamage(DEHIDRATION_DAMAGE * delta, DehidrationDamage);
                }
            }
            
            if (game.isSunUp) {
                game.windParticleCD -= delta;
                for (int i = 0; i < game.windArrayAmount; i++) {
                    game.windArray[i].position.x += game.windArray[i].power * delta;
                    if (game.windArray[i].position.x > NATIVE_WIDTH - 85) {
                        TakeDamage(game.windArray[i].power, WindDamage);
                        game.windArray[i] = game.windArray[game.windArrayAmount - 1];
                        game.windArrayAmount -= 1;
                    } else if (game.isShielding && CheckCollisionPointCircle(game.windArray[i].position, game.shieldPosition, SHIELD_RADIUS)) {
                        game.windArray[i] = game.windArray[game.windArrayAmount - 1];
                        game.windArrayAmount -= 1;
                    }
                }
                if (game.windParticleCD < 0) {
                    game.windParticleCD = WIND_PARTICLES_CD;
                    if (game.windArrayAmount < MAX_WIND_PARTICLES) {
                        game.windArray[game.windArrayAmount].power = 10 + GetRandomValue(1,10);
                        game.windArray[game.windArrayAmount].position.y = NATIVE_HEIGHT - 30 + GetRandomValue(1,20);
                        game.windArray[game.windArrayAmount].position.x = 1;
                        game.windArrayAmount += 1;
                    }
                }
            } else {
                for (int i = 0; i < game.waterArrayAmount; i++) {
                    game.waterArray[i].position.y += game.waterArray[i].amount * 10 * delta;
                    if (game.waterArray[i].position.y > NATIVE_WIDTH - 85) {
                        TakeWater(game.waterArray[i].amount);
                        game.waterArray[i] = game.waterArray[game.waterArrayAmount - 1];
                        game.waterArrayAmount -= 1;
                    } else if (game.isShielding && CheckCollisionPointCircle(game.waterArray[i].position, game.shieldPosition, SHIELD_RADIUS)) {
                        game.waterArray[i] = game.waterArray[game.waterArrayAmount - 1];
                        game.waterArrayAmount -= 1;
                    }
                }
                game.waterParticleCD -= delta;
                if (game.waterParticleCD < 0) {
                    game.waterParticleCD = WATER_PARTICLES_CD;
                    if (game.waterArrayAmount < MAX_WATER_PARTICLES) {
                        game.waterArrayAmount += 1;
                    }
                    game.waterArray[game.waterArrayAmount - 1].amount = GetRandomValue(1, 10);
                    game.waterArray[game.waterArrayAmount - 1].position.y = 0;
                    game.waterArray[game.waterArrayAmount - 1].position.x = 60 + GetRandomValue(1, 20);
                }
            }
        }
        BeginTextureMode(target);
            ClearBackground(DARKGRAY);
            if (game.isSunUp) {
                game.windParticleCD -= delta;
                for (int i = 0; i < game.windArrayAmount; i++) {
                    DrawPixelV(game.windArray[i].position, RAYWHITE);
                }
                const int sunDiv = game.sun.texture.width/SUN_FRAMES;
                DrawTextureRec(game.sun.texture, (Rectangle){ game.sun.currentFrame * sunDiv, 0, sunDiv, game.sun.texture.height}, (Vector2){0, 0}, WHITE);
            } else {
                for (int i = 0; i < game.waterArrayAmount; i++) {
                    DrawPixelV(game.waterArray[i].position, RAYWHITE);
                    i += 1;
                }
                game.waterParticleCD -= delta;
                if (game.waterParticleCD < 0) {
                    game.waterParticleCD = WATER_PARTICLES_CD;
                    if (game.waterArrayAmount < MAX_WATER_PARTICLES) {
                        game.waterArrayAmount += 1;
                    }
                    game.waterArray[game.waterArrayAmount - 1].amount = GetRandomValue(1, 10);
                    game.waterArray[game.waterArrayAmount - 1].position.y = 0;
                    game.waterArray[game.waterArrayAmount - 1].position.x = 60 + GetRandomValue(1, 20);
                }
                const int cloudDiv = game.cloud.texture.width/CLOUD_FRAMES;
                DrawTextureRec(game.cloud.texture, (Rectangle){game.cloud.currentFrame * cloudDiv, 0, cloudDiv, game.cloud.texture.height}, (Vector2){40, 0}, WHITE);
            }
            const int flowerDiv = game.flower.texture.width/FLOWER_FRAMES;
            DrawTextureRec(game.flower.texture, (Rectangle){game.flower.currentFrame * flowerDiv, 0, flowerDiv, game.flower.texture.height}, (Vector2){60, NATIVE_HEIGHT - game.flower.texture.height}, WHITE);
            DrawRectangleRec(healthRec, WHITE);
            DrawRectangleRec(hidrationRec, WHITE);
            DrawTextureV(game.healthTexture,(Vector2){healthRec.x-2, NATIVE_HEIGHT - DEFAULT_BAR_HEIGHT - 10},WHITE);
            DrawTextureV(game.waterTexture,(Vector2){hidrationRec.x-2, NATIVE_HEIGHT - DEFAULT_BAR_HEIGHT - 10},WHITE);
            DrawText(TextFormat("$: %03.0f", game.score), NATIVE_WIDTH - 30, DEFAULT_BAR_HEIGHT-30, 1, WHITE);

            if (game.isShielding) {
                DrawCircleV(game.shieldPosition, SHIELD_RADIUS, LIGHTGRAY);
            }
        EndTextureMode();
    }

    BeginDrawing();
        ClearBackground(DARKGRAY);
        switch (game.state)
        {
            case StateInGame:
                DrawTexturePro(target.texture, sourceRec, destRec, (Vector2){0}, 0.0f, WHITE);
                
                if (MenuButtom((Rectangle){game.width - 210, 10, 100, 40}, "Music"))
                {
                    if(game.isMusicPaused){
                        ResumeMusicStream(music);
                        game.isMusicPaused = false;
                    }else{
                        PauseMusicStream(music);
                        game.isMusicPaused = true;
                    }
                }
                if (MenuButtom((Rectangle){game.width - 105, 10, 100, 40}, "Pause"))
                {
                    game.isPaused = !game.isPaused;
                }
                if(game.isPaused) {
                    const Rectangle tempPauseRec = (Rectangle){restartMenuRec.x, restartMenuRec.y-restartMenuRec.height-15, restartMenuRec.width, restartMenuRec.height};
                    if (MenuButtom(tempPauseRec, "Continue Game"))
                    {
                        // Initialize game
                        game.isPaused = false;
                    }
                    if (MenuButtom(restartMenuRec, "Restart Game"))
                    {
                        // Initialize game
                        ResetGame();
                        game.state = StateInGame;
                    }
                    if (MenuButtom(exitMenuRec, "Exit Game"))
                    {
                        // Exit game
                        isPlaying = false;
                        return;
                    }
                }

                break;
            case StateStartMenu:
                if (MenuButtom(startMenuRec, "Start Game"))
                {
                    // Initialize game
                    game.state = StateInGame;
                }
                if (MenuButtom(exitMenuRec, "Exit Game")){
                    // Exit game
                    isPlaying = false;
                    return;
                }
                
                break;
            case StateGameOver:
                switch (game.gameOverType)
                {
                    case DehidrationDamage:
                        DrawText("Your flower died by dehidration.", restartMenuRec.x, restartMenuRec.y - 42, FONT_SIZE, WHITE);
                        break;
                    case DrawningDamage:
                        DrawText("Your flower died by drawning.", restartMenuRec.x, restartMenuRec.y - 42, FONT_SIZE, WHITE);
                        break;
                    case WindDamage:
                        DrawText("Your flower died by too much wind.", restartMenuRec.x, restartMenuRec.y - 42, FONT_SIZE, WHITE);
                        break;
                    default:
                        break;
                }
                DrawText(TextFormat("Highest Score: %03.0f", game.highestScore), restartMenuRec.x, restartMenuRec.y - 20, FONT_SIZE, WHITE);
                if (MenuButtom(restartMenuRec, "Restart Game"))
                {
                    // Initialize game
                    ResetGame();
                    game.state = StateInGame;
                }
                if (MenuButtom(exitMenuRec, "Exit Game"))
                {
                    // Exit game
                    isPlaying = false;
                    return;
                }
                break;
        }
        // DrawText(TextFormat("FPS: %d", GetFPS()), 10, 12, FONT_SIZE, RED);
    EndDrawing();

}

int main(void) {
    // Start game
    game.width = 800;
    game.height = 450;
    // Start Raylib Window
    InitWindow(game.width, game.height, "Pixel Bloom");

    InitAudioDevice();   

    target = LoadRenderTexture(NATIVE_WIDTH, NATIVE_HEIGHT);
    LoadTextures();
    
    music = LoadMusicStream("resources/musics/ambient.mp3");
    PlayMusicStream(music);

    UpdateScreenValues();
    PlaceUIButtons();
    ResetGame();
    sourceRec = (Rectangle){ 0.0f, 0.0f, target.texture.width, - target.texture.height };
    destRec = (Rectangle){ -game.virtualRatio, -game.virtualRatio, game.width + (game.virtualRatio*2), game.height + (game.virtualRatio*2) };

    game.state = StateStartMenu;
    game.highestScore = 0;

#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(UpdateFrame, 0, 1);
#else
    ToggleFullscreen();
    
    game.width = GetMonitorWidth(GetCurrentMonitor());
    game.height = GetMonitorHeight(GetCurrentMonitor());
    UpdateScreenValues();

    SetTargetFPS(60);
    // Main game loop
    while (!WindowShouldClose() && isPlaying) {
        UpdateFrame();
    }
#endif
    
    UnloadTextures();
    UnloadMusicStream(music);
    CloseAudioDevice();
    CloseWindow();

    return 0;
}