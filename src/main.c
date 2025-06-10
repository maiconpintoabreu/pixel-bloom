
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
// const int PLAYER_MAX_SHOOTS			= 100;

// Flower consts
const int FLOWER_FRAMES = 7;
const float FLOWER_FRAME_SPEED  = .3;
const float FLOWER_WATER_DRAIN_SPEED = .2;
const float FLOWER_MAX_WATER_LEVEL = 200;

// Sun consts
const int SUN_FRAMES = 8;
const float SUN_FRAME_SPEED  = .3;
const float SUN_AMOUNT = 10.0;

// Cloud consts
const int CLOUD_FRAMES = 8;
const float CLOUD_FRAME_SPEED  = .3;
const float CLOUD_AMOUNT = 5.0;

typedef struct Flower {
    float frameTimer;
    float waterDrainSpeed;
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

typedef struct Game {
    WindParticles windArray[MAX_WIND_PARTICLES];
    WaterParticles waterArray[MAX_WATER_PARTICLES];
    Flower flower;
    Sun sun;
    Cloud cloud;
    Vector2 startLine;
    Vector2 endLine;
    Vector2 currentLine[2];
	GameStateType state;
    int width;
    int height;
    int halfWidth;
    int halfHeight;
    float virtualRatio;
    float currentScore;
    float highestScore;
    float lineDuration;
    int windArrayAmount;
    int waterArrayAmount;
    float windParticleCD;
    float waterParticleCD;
    bool isSunUp;
    bool isDraging;
} Game;

static Game game = {0};

static const float menu_size_width = 200.0f;
static const float item_menu_size_height = 50.0f;
static Rectangle exitMenuRec = {0};
static Rectangle startMenuRec = {0};
static Rectangle restartMenuRec = {0};
static RenderTexture2D target = {0};

// The target's height is flipped (in the source Rectangle), due to OpenGL reasons
static Rectangle sourceRec = {0};
static Rectangle destRec = {0};

 
int MenuButtom(Rectangle buttom, const char *buttom_text) {
    if (IsMouseButtonDown(MOUSE_LEFT_BUTTON) && CheckCollisionPointRec(GetMousePosition(), buttom))
    {
        return true;
    }
    DrawRectangleRec(buttom, GRAY);

    DrawText(buttom_text, buttom.x + 20, buttom.y + buttom.height / 2 - 10, 20, WHITE);
    return 0;
}

void PlaceUIButtons(){
    game.width = GetScreenWidth();
    game.height = GetScreenHeight();
	game.halfWidth = game.width / 2.0;
	game.halfHeight = game.height / 2.0;
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
    game.windParticleCD = 1;
    game.waterParticleCD = 1;
    game.isSunUp = true;
}
void LoadTextures() {
    game.flower.texture = LoadTexture("resources/flower.png");
    game.sun.texture = LoadTexture("resources/sun.png");
    game.cloud.texture = LoadTexture("resources/cloud.png");
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
}
void UpdateRatio() {
    game.virtualRatio = game.height/NATIVE_HEIGHT;
}
void TakeDamage(float damage) {
    if (!game.flower.isAlive) return;
    game.flower.health =  game.flower.health - damage;
    if (game.flower.health <= 0) {
        game.flower.isAlive = false;
        game.flower.health = 0;
    }
}
void TakeWater(float water) {
    if (!game.flower.isAlive) return;
    game.flower.waterLevel += water;
    if (game.flower.waterLevel > FLOWER_MAX_WATER_LEVEL) {
        TakeDamage(10);
        game.flower.waterLevel = FLOWER_MAX_WATER_LEVEL;
    } else {
        game.flower.health += 1;
    }
}
void UpdateFrame() {
    if(IsWindowResized()){
        PlaceUIButtons();
    }
    // Tick
    if(game.state == StateInGame){
        if (IsKeyPressed(KEY_SPACE)) {
            game.isSunUp = !game.isSunUp;
            game.flower.currentFrame = 0;
            game.cloud.currentFrame = 0;
            game.sun.currentFrame = 0;
            game.windArrayAmount = 0;
            game.waterArrayAmount = 0;
            game.windParticleCD = 1;
            game.waterParticleCD = 1;
        }

        if (IsWindowResized()) {
            game.width = GetScreenWidth();
            game.height = GetScreenHeight();
            UpdateRatio();
        }
        
        SetMouseScale(1 / game.virtualRatio, 1 / game.virtualRatio);
        const int points = GetTouchPointCount();
        if (points > 1 || game.isDraging) {
            if (!game.isDraging) {
                game.isDraging = true;
                game.startLine = Vector2Scale(GetMousePosition(), 1 / game.virtualRatio);
                game.endLine = (Vector2){0};
                game.lineDuration = 40;
            }
            if (points == 0) {
                game.endLine = Vector2Scale(GetMousePosition(), 1 / game.virtualRatio);
                game.isDraging = false;
            }
        } else {
            if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
                game.startLine = GetMousePosition();
                game.endLine = (Vector2){0};
                game.lineDuration = 40;
            }
            if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON)) {
                game.endLine = GetMousePosition();
            }
        }

        const float delta = GetFrameTime();

        if (game.lineDuration > 0) {
            if (game.endLine.x == 0 && game.endLine.y == 0) {
                game.currentLine[0] = game.startLine;
                game.currentLine[1] = GetMousePosition();
            } else {
                game.lineDuration -= delta;
                game.currentLine[0] = game.startLine;
                game.currentLine[1] = game.endLine;
            }
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
        }
        if (game.flower.waterLevel != 0.0) {
            game.flower.waterLevel = game.flower.waterLevel - (game.flower.waterDrainSpeed * delta);
        }
        if (game.flower.waterLevel < 0.0) {
            game.flower.waterLevel = 0.0;
        }
        BeginTextureMode(target);
            ClearBackground(DARKGRAY);
            if (game.isSunUp) {
                game.windParticleCD -= delta;
                for (int i = 0; i < game.windArrayAmount; i++) {
                    WindParticles *value = &game.windArray[i];
                    value->position.x += value->power * delta;
                    if (value->position.x > NATIVE_WIDTH - 85) {
                        TakeDamage(value->power);
                        game.windArray[i] = game.windArray[game.windArrayAmount - 1];
                        game.windArrayAmount -= 1;
                    } else if (game.lineDuration > 0 && CheckCollisionPointLine(value->position, game.currentLine[0], game.currentLine[1], 1)) {
                        game.windArray[i] = game.windArray[game.windArrayAmount - 1];
                        game.windArrayAmount -= 1;
                    } else {
                        DrawPixelV(value->position, RAYWHITE);
                        i += 1;
                    }
                }
                if (game.windParticleCD < 0) {
                    game.windParticleCD = 1;
                    if (game.windArrayAmount < MAX_WIND_PARTICLES) {
                        game.windArray[game.windArrayAmount].power = 10 + GetRandomValue(1,10);
                        game.windArray[game.windArrayAmount].position.y = NATIVE_HEIGHT - 30 + GetRandomValue(1,20);
                        game.windArray[game.windArrayAmount].position.x = 1;
                        game.windArrayAmount += 1;
                    }
                }
                const int sunDiv = game.sun.texture.width/SUN_FRAMES;
                DrawTextureRec(game.sun.texture, (Rectangle){ game.sun.currentFrame * sunDiv, 0, sunDiv, game.sun.texture.height}, (Vector2){0, 0}, WHITE);
            } else {
                for (int i = 0; i < game.waterArrayAmount; i++) {
                    WaterParticles *value = &game.waterArray[i];
                    value->position.y += value->amount * delta;
                    if (value->position.x > NATIVE_WIDTH - 85) {
                        TakeWater(value->amount);
                        game.waterArray[i] = game.waterArray[game.waterArrayAmount - 1];
                        game.waterArrayAmount -= 1;
                    } else if (game.lineDuration > 0 && CheckCollisionPointLine(value->position, game.currentLine[0], game.currentLine[1], 1)) {
                        game.waterArray[i] = game.waterArray[game.waterArrayAmount - 1];
                        game.waterArrayAmount -= 1;
                    } else {
                        DrawPixelV(value->position, RAYWHITE);
                        i += 1;
                    }
                }
                game.waterParticleCD -= delta;
                if (game.waterParticleCD < 0) {
                    game.waterParticleCD = 1;
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

            if (game.lineDuration > 0) {
                DrawLineEx(game.currentLine[0], game.currentLine[1], 5, LIGHTGRAY);
            }
        EndTextureMode();
    }

    BeginDrawing();
        ClearBackground(DARKGRAY);
        switch (game.state)
        {
            case StateInGame:
                DrawTexturePro(target.texture, sourceRec, destRec, (Vector2){0}, 0.0f, WHITE);
                float waterLevelPercentage = game.flower.waterLevel/FLOWER_MAX_WATER_LEVEL * 100;
                Color waterLevelColor = WHITE;
                if (waterLevelPercentage >= 50) {
                    waterLevelColor = GRAY;
                } else if (waterLevelPercentage >= 10) {
                    waterLevelColor = WHITE;
                }
                DrawText(TextFormat("S2: %03.0f", game.flower.health), game.width - 100, 10, FONT_SIZE, waterLevelColor);
                DrawText(TextFormat("(o): %03.0f%%", waterLevelPercentage), game.width - 100, 30, FONT_SIZE, waterLevelColor);
                DrawText(TextFormat("->: %03.0i", game.windArrayAmount), game.width - 100, 50, FONT_SIZE, waterLevelColor);

                break;
            case StateStartMenu:
                if (MenuButtom(startMenuRec, "Start Game"))
                {
                    // Initialize game
                    game.state = StateInGame;
                }
                if (MenuButtom(exitMenuRec, "Exit Game")){
                    // Exit game
                    CloseWindow();
                }
                
                break;
            case StateGameOver:
                if (MenuButtom(restartMenuRec, "Restart Game"))
                {
                    // Initialize game
                    ResetGame();
                    game.state = StateInGame;
                }
                if (MenuButtom(exitMenuRec, "Exit Game"))
                {
                    // Exit game
                    CloseWindow();
                }
                break;
        }
        DrawText(TextFormat("FPS: %d", GetFPS()), 10, 12, FONT_SIZE, RED);
    EndDrawing();

}

int main(void) {
    // Start game
    game.width = 800;
    game.height = 450;
    // Start Raylib Window
    InitWindow(game.width, game.height, "Pixel Bloom");

    target = LoadRenderTexture(NATIVE_WIDTH, NATIVE_HEIGHT);
    LoadTextures();

    PlaceUIButtons();
    UpdateRatio();
    ResetGame();
    sourceRec = (Rectangle){ 0.0f, 0.0f, target.texture.width, - target.texture.height };
    destRec = (Rectangle){ -game.virtualRatio, -game.virtualRatio, game.width + (game.virtualRatio*2), game.height + (game.virtualRatio*2) };

    game.state = StateStartMenu;

#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(UpdateFrame, 0, 1);
#else
    SetTargetFPS(60);
    // Main game loop
    while (!WindowShouldClose()) {
        UpdateFrame();
    }
#endif
    
    UnloadTextures();

    CloseWindow();

    return 0;
}