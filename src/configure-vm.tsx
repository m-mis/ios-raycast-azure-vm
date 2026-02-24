import { Action, ActionPanel, Icon, List, showToast, Toast, popToRoot } from "@raycast/api";
import { useState } from "react";
import { useCachedPromise } from "@raycast/utils";
import { listSubscriptions, listResourceGroups, listVirtualMachines } from "./lib/azure-api";
import { saveVmConfig } from "./lib/storage";
import { Subscription, ResourceGroup, VirtualMachine } from "./lib/types";

type Step = "subscription" | "resourceGroup" | "vm";

export default function ConfigureVm() {
  const [step, setStep] = useState<Step>("subscription");
  const [selectedSub, setSelectedSub] = useState<Subscription>();
  const [selectedRg, setSelectedRg] = useState<ResourceGroup>();

  if (step === "subscription") {
    return (
      <SubscriptionPicker
        onSelect={(sub) => {
          setSelectedSub(sub);
          setStep("resourceGroup");
        }}
      />
    );
  }

  if (step === "resourceGroup" && selectedSub) {
    return (
      <ResourceGroupPicker
        subscriptionId={selectedSub.subscriptionId}
        onSelect={(rg) => {
          setSelectedRg(rg);
          setStep("vm");
        }}
        onBack={() => setStep("subscription")}
      />
    );
  }

  if (step === "vm" && selectedSub && selectedRg) {
    return (
      <VmPicker
        subscriptionId={selectedSub.subscriptionId}
        subscriptionName={selectedSub.displayName}
        resourceGroup={selectedRg.name}
        onBack={() => setStep("resourceGroup")}
      />
    );
  }

  return null;
}

function SubscriptionPicker({ onSelect }: { onSelect: (sub: Subscription) => void }) {
  const { data, isLoading, error } = useCachedPromise(listSubscriptions);

  if (error) {
    showToast(Toast.Style.Failure, "Failed to load subscriptions", error.message);
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search subscriptions…">
      <List.EmptyView
        title={error ? "Authentication Error" : "No Subscriptions Found"}
        description={error ? "Check your credentials in extension preferences." : undefined}
        icon={error ? Icon.ExclamationMark : Icon.MagnifyingGlass}
      />
      {data?.map((sub) => (
        <List.Item
          key={sub.subscriptionId}
          title={sub.displayName}
          subtitle={sub.subscriptionId}
          accessories={[{ text: sub.state }]}
          actions={
            <ActionPanel>
              <Action title="Select Subscription" onAction={() => onSelect(sub)} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function ResourceGroupPicker({
  subscriptionId,
  onSelect,
  onBack,
}: {
  subscriptionId: string;
  onSelect: (rg: ResourceGroup) => void;
  onBack: () => void;
}) {
  const { data, isLoading, error } = useCachedPromise(listResourceGroups, [subscriptionId]);

  if (error) {
    showToast(Toast.Style.Failure, "Failed to load resource groups", error.message);
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search resource groups…">
      <List.EmptyView
        title={error ? "Failed to Load" : "No Resource Groups"}
        description={error ? error.message : undefined}
        icon={error ? Icon.ExclamationMark : Icon.MagnifyingGlass}
      />
      {data?.map((rg) => (
        <List.Item
          key={rg.id}
          title={rg.name}
          subtitle={rg.location}
          actions={
            <ActionPanel>
              <Action title="Select Resource Group" onAction={() => onSelect(rg)} />
              <Action
                title="Back to Subscriptions"
                icon={Icon.ArrowLeft}
                onAction={onBack}
                shortcut={{ modifiers: ["cmd"], key: "[" }}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function VmPicker({
  subscriptionId,
  subscriptionName,
  resourceGroup,
  onBack,
}: {
  subscriptionId: string;
  subscriptionName: string;
  resourceGroup: string;
  onBack: () => void;
}) {
  const { data, isLoading, error } = useCachedPromise(listVirtualMachines, [subscriptionId, resourceGroup]);

  if (error) {
    showToast(Toast.Style.Failure, "Failed to load virtual machines", error.message);
  }

  async function handleSelect(vm: VirtualMachine) {
    await saveVmConfig({
      subscriptionId,
      subscriptionName,
      resourceGroup,
      vmName: vm.name,
    });
    await showToast(Toast.Style.Success, "VM Configured", `${vm.name} in ${resourceGroup}`);
    popToRoot();
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search virtual machines…">
      <List.EmptyView
        title={error ? "Failed to Load" : "No Virtual Machines"}
        description={error ? error.message : "This resource group has no VMs."}
        icon={error ? Icon.ExclamationMark : Icon.ComputerChip}
      />
      {data?.map((vm) => (
        <List.Item
          key={vm.id}
          title={vm.name}
          subtitle={vm.location}
          accessories={[{ text: vm.properties.hardwareProfile?.vmSize }]}
          actions={
            <ActionPanel>
              <Action title="Select Vm" onAction={() => handleSelect(vm)} />
              <Action
                title="Back to Resource Groups"
                icon={Icon.ArrowLeft}
                onAction={onBack}
                shortcut={{ modifiers: ["cmd"], key: "[" }}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
