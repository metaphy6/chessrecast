Thanks. so far so good. Now is time we do some refactoring! Firstly and most importantly, I want to separate all the variants into single dart files under a new folder called 'variants'.
Also we need to make some renaming. If you ask me such folder organization as feature/chess/** is not human understandable. Also folder names 'domain' and 'entities' aren't logical, either. The same with 'app', too. I try to tell you what I want:

1. Remove 'features' folder entirely.
2. Rename 'chess' folder to 'game'
3. Move 'game_options' folder under the new 'game' folder, and rename it just 'options'
4. Remove 'domain' folder entirely, and move the folders under it upper folder 'game'
5. Rename 'entities' folder to 'board'. 'variants' folder will be under renamed new folder 'board'
6. Rename 'app' folder to 'struct', and move folders and files under 'core' folder there; remove 'core' folder entirely.
7. Remove 'chess_' prefix from dart file names
