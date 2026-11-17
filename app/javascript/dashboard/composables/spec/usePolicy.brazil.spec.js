import { ref } from 'vue';
import { usePolicy } from '../usePolicy';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: vi.fn(),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: vi.fn(),
}));

vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: vi.fn(),
}));

describe('usePolicy - Enterprise Unlock Brazil', () => {
  beforeEach(() => {
    useMapGetter.mockImplementation(key => {
      const map = {
        getCurrentUser: ref({
          accounts: [
            { id: 1, role: 'administrator', permissions: ['administrator'] },
          ],
        }),
        'accounts/isFeatureEnabledonAccount': ref(() => true),
        'globalConfig/isOnChatwootCloud': ref(false),
        'globalConfig/isACustomBrandedInstance': ref(false),
      };
      return map[key] || ref(null);
    });
    useAccount.mockReturnValue({ accountId: ref(1) });
    useConfig.mockReturnValue({
      isEnterprise: true,
      enterprisePlanName: 'enterprise',
    });
  });

  it('never displays paywalls for SLA, Custom Roles, Audit Logs or Captain', () => {
    const { shouldShowPaywall, shouldShow } = usePolicy();

    expect(shouldShowPaywall('sla')).toBe(false);
    expect(shouldShowPaywall('audit_logs')).toBe(false);
    expect(shouldShowPaywall('custom_roles')).toBe(false);
    expect(shouldShowPaywall('captain_integration')).toBe(false);

    expect(shouldShow('sla', ['administrator'], ['enterprise'])).toBe(true);
    expect(shouldShow('audit_logs', ['administrator'], ['enterprise'])).toBe(
      true
    );
  });
});
