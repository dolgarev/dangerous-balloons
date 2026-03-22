package Settings is

  -- Maze dimensions
  Max_Rows : constant := 23;
  Max_Cols : constant := 23;

  -- Game Rules
  Max_Levels        : constant := 10;
  Initial_Lives     : constant := 3;
  Initial_Level     : constant := 1;
  Initial_Balloons  : constant := 4;
  Max_Bombs         : constant := 5;
  Max_Balloons      : constant := 20;
  Bomb_Timer_Sec    : constant := 5;
  Mode_Switch_Sec   : constant := 8;
  Brick_Probability : constant := 40;

  -- Items and Progression
  Item_Appear_Prob : constant := 10; -- 10% chance for an item to appear
  Item_Life_Prob   : constant := 20; -- 20% of items are lives
  Item_Score_Prob  : constant :=
   75; -- 75% of items are scores (remaining 5% is Door)

  Max_Lives_Limit    : constant := 5;
  Score_Extra_Life   : constant := 100; -- if lives are maxed
  Score_Bonus_Points : constant := 200;

  -- Scoring
  Score_Brick     : constant := 10;
  Score_Balloon_F : constant := 50;
  Score_Balloon_H : constant := 100;

  -- Animations (in 50ms ticks)
  Explosion_Duration_Ticks : constant := 10;
  Balloon_Death_Ticks      : constant := 60;
  Player_Death_Ticks       : constant := 80;
  Balloon_Move_Tick_Rate   : constant := 10;

  -- Visuals
  Char_Wall        : constant Character := '#';
  Char_Brick       : constant Character := ' ';
  Char_Player      : constant Character := '@';
  Char_Balloon     : constant Character := 'Q';
  Char_Explosion   : constant Character := '*';
  Char_Dead_Player : constant Character := 'X';
  Char_Item_Life   : constant Character := 'L';
  Char_Item_Score  : constant Character := '$';
  Char_Door        : constant Character := 'E';

  -- Color Pair IDs
  Color_Wall_ID       : constant := 1;
  Color_Brick_ID      : constant := 2;
  Color_Empty_ID      : constant := 3;
  Color_Player_ID     : constant := 4;
  Color_Bomb_ID       : constant := 5;
  Color_Dead_ID       : constant := 6;
  Color_Balloon_F_ID  : constant := 7;
  Color_Balloon_H_ID  : constant := 8;
  Color_Balloon_D_ID  : constant := 9;
  Color_Status_ID     : constant := 10;
  Color_Item_Life_ID  : constant := 11;
  Color_Item_Score_ID : constant := 12;
  Color_Door_ID       : constant := 13;

end Settings;
