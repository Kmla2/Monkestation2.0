/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { useAtom, useAtomValue } from 'jotai';
import { Pane } from 'tgui/layouts';
import { Button, Section, Stack } from 'tgui-core/components';
import { visibleAtom } from './audio/atoms';
import { NowPlayingWidget } from './audio/NowPlayingWidget';
import { ChatPanel } from './chat/ChatPanel';
import { ChatTabs } from './chat/ChatTabs';
import { useChatPersistence } from './chat/use-chat-persistence';
import { gameAtom } from './game/atoms';
import { useKeepAlive } from './game/use-keep-alive';
import { Notifications } from './Notifications';
import { PingIndicator } from './ping/PingIndicator';
import { ReconnectButton } from './reconnect';
import { settingsVisibleAtom } from './settings/atoms';
import { SettingsPanel } from './settings/SettingsPanel';
import { useSettings } from './settings/use-settings';

export function Panel(props) {
  const [audioVisible, setAudioVisible] = useAtom(visibleAtom);
  const game = useAtomValue(gameAtom);
  const { settings } = useSettings();
  const [settingsVisible, setSettingsVisible] = useAtom(settingsVisibleAtom);
  useChatPersistence();
  useKeepAlive();

  const tabs_thingy = (
    <>
      <Stack.Item>
        <Section fitted className="clip-include">
          <Stack mr={1} align="center">
            <Stack.Item grow={game.pointerLockState ? 0 : 1} overflowX="auto">
              <ChatTabs />
            </Stack.Item>
            <Stack.Item>
              <PingIndicator />
            </Stack.Item>
            {!game.pointerLockState && (
              <>
                <Stack.Item>
                  <Button
                    color="grey"
                    selected={audio.visible}
                    icon="music"
                    tooltip="Music player"
                    tooltipPosition="bottom-start"
                    onClick={() => audio.toggle()}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon={settings.visible ? 'times' : 'cog'}
                    selected={settings.visible}
                    tooltip={
                      settings.visible ? 'Close settings' : 'Open settings'
                    }
                    tooltipPosition="bottom-start"
                    onClick={() => settings.toggle()}
                  />
                </Stack.Item>
              </>
            )}
          </Stack>
        </Section>
      </Stack.Item>
      {audio.visible && (
        <Stack.Item>
          <Section className="clip-include">
            <NowPlayingWidget />
          </Section>
        </Stack.Item>
      )}
    </>
  );

  return (
    <Pane theme={settings.theme} canSuspend={false}>
      <Stack fill vertical>
        <Stack.Item>
          <Section fitted>
            <Stack mr={1} align="center">
              <Stack.Item grow>
                <ChatTabs />
              </Stack.Item>
              <Stack.Item>
                <PingIndicator />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="grey"
                  selected={audioVisible}
                  icon="music"
                  tooltip="Music player"
                  tooltipPosition="bottom-start"
                  onClick={() => setAudioVisible((v) => !v)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon={settingsVisible ? 'times' : 'cog'}
                  selected={settingsVisible}
                  tooltip={settingsVisible ? 'Close settings' : 'Open settings'}
                  tooltipPosition="bottom-start"
                  onClick={() => setSettingsVisible((v) => !v)}
                />
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
        {audioVisible && (
          <Stack.Item>
            <Section>
              <NowPlayingWidget />
            </Section>
          </Stack.Item>
        )}
        {settingsVisible && (
          <Stack.Item>
            <SettingsPanel />
          </Stack.Item>
        )}
        <Stack.Item grow>
          <Section fill fitted position="relative">
            <Pane.Content scrollable id="chat-pane">
              <ChatPanel lineHeight={settings.lineHeight} />
            </Pane.Content>
            <Notifications>
              {game.connectionLostAt && (
                <Notifications.Item rightSlot={<ReconnectButton />}>
                  You are either AFK, experiencing lag or the connection has
                  closed.
                </Notifications.Item>
              )}
              {game.roundRestartedAt && (
                <Notifications.Item>
                  The connection has been closed because the server is
                  restarting. Please wait while you automatically reconnect.
                </Notifications.Item>
              )}
            </Notifications>
          </Section>
        </Stack.Item>
        {'byond' in window && tabs_thingy}
      </Stack>
    </Pane>
  );
}
