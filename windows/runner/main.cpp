#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // ── Always open a console window, Mission Planner style ──────────────────
  // Try to attach to an existing parent console (e.g. launched from CMD).
  // If there is none, allocate a brand-new one so it always shows up.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    CreateAndAttachConsole();
  }
  // Set title & resize to a comfortable 120-col layout
  ::SetConsoleTitle(L"WINGSPANN GCS \x2014 Console");
  HANDLE hConsole = ::GetStdHandle(STD_OUTPUT_HANDLE);
  CONSOLE_SCREEN_BUFFER_INFO csbi;
  if (::GetConsoleScreenBufferInfo(hConsole, &csbi)) {
    COORD bufSize = {120, 3000};          // 120 cols, 3000-line scroll back
    ::SetConsoleScreenBufferSize(hConsole, bufSize);
    SMALL_RECT winRect = {0, 0, 119, 35}; // visible 120x36 window
    ::SetConsoleWindowInfo(hConsole, TRUE, &winRect);
  }
  // ─────────────────────────────────────────────────────────────────────────

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"gcs_flutter", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
