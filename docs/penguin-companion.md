# Silent employee penguin companion

The employee dashboard offers Feed, Play, Pet and Rest/Wake. There is no Talk
button, microphone, recording, voice playback or audio permission in this feature.
The login stays penguin-free and the branch family habitat is unchanged.

The existing orange crown, green bill/feet and gray-white body are retained.
Chick and adult reaction sheets contain four expressions for each care action.
The character uses pose animation, not wildlife video or a live 3D model.
Daily growth and server-confirmed hatching still determine its size and stage.

The first Feed/Play action saves through the existing employee-only API.
Its 24-hour care records and daily growth rules are unchanged. Subsequent
Feed/Play clicks are visual interactions and do not issue extra care writes.
Pet and Rest are local interactions. No care animations or success messages
are started on a failed request, and pending writes disable the controls.

Speech bubbles, a small fish, a snowball and hearts explain the responses.
Happiness is derived from daily feeding/play plus local petting; energy shows
a ready/resting state. These are illustrative care indicators, not stored game
currency or medical measurements. Local petting/rest resets with the card.
Rest lasts until Wake, tapping the sleeping pet, feeding or playing.
Reaction timers cannot wake a resting pet; they are cancelled on replacement
and disposal. The reaction atlas is reused between consecutive interactions.
Reduced motion displays a static expressive pose and static care props.

Tests cover four silent controls, care failures, duplicate request protection,
sealed eggs, pose isolation, daily-care repeat interactions, and rest cancellation.
Android clients need the new build for these bundled controls and artwork.
