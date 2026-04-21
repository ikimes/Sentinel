using MassTransit;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Sentinel.Shared.Messaging;

public static class MassTransitObserverExtensions
{
    public static void AddSentinelMassTransitObservers(this IServiceCollection services, string serviceName)
    {
        services.AddSingleton(provider =>
        {
            var loggerFactory = provider.GetRequiredService<ILoggerFactory>();
            var observerLogger = loggerFactory.CreateLogger<SentinelMassTransitObserver>();
            return new SentinelMassTransitObserver(observerLogger, serviceName);
        });
        services.AddBusObserver(provider => provider.GetRequiredService<SentinelMassTransitObserver>());
        services.AddReceiveEndpointObserver(provider => provider.GetRequiredService<SentinelMassTransitObserver>());
        services.AddReceiveObserver(provider => provider.GetRequiredService<SentinelMassTransitObserver>());
        services.AddSendObserver(provider => provider.GetRequiredService<SentinelMassTransitObserver>());
        services.AddPublishObserver(provider => provider.GetRequiredService<SentinelMassTransitObserver>());
    }
}

internal sealed class SentinelMassTransitObserver :
    IBusObserver,
    IReceiveObserver,
    IReceiveEndpointObserver,
    ISendObserver,
    IPublishObserver
{
    private readonly ILogger _logger;
    private readonly string _serviceName;
    private readonly int _processId;

    public SentinelMassTransitObserver(ILogger logger, string serviceName)
    {
        _logger = logger;
        _serviceName = serviceName;
        _processId = Environment.ProcessId;
    }

    public void PostCreate(IBus bus)
    {
        _logger.LogInformation("MT_OBSERVER_BUS_CREATED service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
    }

    public void CreateFaulted(Exception exception)
    {
        _logger.LogError(exception, "MT_OBSERVER_BUS_CREATE_FAULTED service={ServiceName} processId={ProcessId}", _serviceName, _processId);
    }

    public Task PreStart(IBus bus)
    {
        _logger.LogInformation("MT_OBSERVER_BUS_PRE_START service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
        return Task.CompletedTask;
    }

    public Task PostStart(IBus bus, Task<BusReady> busReady)
    {
        _logger.LogInformation("MT_OBSERVER_BUS_POST_START service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
        return Task.CompletedTask;
    }

    public Task StartFaulted(IBus bus, Exception exception)
    {
        _logger.LogError(exception, "MT_OBSERVER_BUS_START_FAULTED service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
        return Task.CompletedTask;
    }

    public Task PreStop(IBus bus)
    {
        _logger.LogInformation("MT_OBSERVER_BUS_PRE_STOP service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
        return Task.CompletedTask;
    }

    public Task PostStop(IBus bus)
    {
        _logger.LogInformation("MT_OBSERVER_BUS_POST_STOP service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
        return Task.CompletedTask;
    }

    public Task StopFaulted(IBus bus, Exception exception)
    {
        _logger.LogError(exception, "MT_OBSERVER_BUS_STOP_FAULTED service={ServiceName} processId={ProcessId} address={Address}", _serviceName, _processId, bus.Address);
        return Task.CompletedTask;
    }

    public Task Ready(ReceiveEndpointReady ready)
    {
        _logger.LogInformation(
            "MT_OBSERVER_ENDPOINT_READY service={ServiceName} endpoint={InputAddress}",
            _serviceName,
            ready.InputAddress
        );
        return Task.CompletedTask;
    }

    public Task Completed(ReceiveEndpointCompleted completed)
    {
        _logger.LogInformation(
            "MT_OBSERVER_ENDPOINT_COMPLETED service={ServiceName} endpoint={InputAddress}",
            _serviceName,
            completed.InputAddress
        );
        return Task.CompletedTask;
    }

    public Task Faulted(ReceiveEndpointFaulted faulted)
    {
        _logger.LogError(
            faulted.Exception,
            "MT_OBSERVER_ENDPOINT_FAULTED service={ServiceName} endpoint={InputAddress}",
            _serviceName,
            faulted.InputAddress
        );
        return Task.CompletedTask;
    }

    public Task Stopping(ReceiveEndpointStopping stopping)
    {
        _logger.LogInformation(
            "MT_OBSERVER_ENDPOINT_STOPPING service={ServiceName} endpoint={InputAddress}",
            _serviceName,
            stopping.InputAddress
        );
        return Task.CompletedTask;
    }

    public Task PreReceive(ReceiveContext context)
    {
        _logger.LogInformation(
            "MT_OBSERVER_RECEIVE_PRE service={ServiceName} inputAddress={InputAddress} transportMessageId={TransportMessageId}",
            _serviceName,
            context.InputAddress,
            context.TransportHeaders.Get<string>("MessageId")
        );
        return Task.CompletedTask;
    }

    public Task PostReceive(ReceiveContext context)
    {
        _logger.LogInformation(
            "MT_OBSERVER_RECEIVE_POST service={ServiceName} inputAddress={InputAddress} transportMessageId={TransportMessageId}",
            _serviceName,
            context.InputAddress,
            context.TransportHeaders.Get<string>("MessageId")
        );
        return Task.CompletedTask;
    }

    public Task ReceiveFault(ReceiveContext context, Exception exception)
    {
        _logger.LogError(
            exception,
            "MT_OBSERVER_RECEIVE_FAULT service={ServiceName} inputAddress={InputAddress} transportMessageId={TransportMessageId}",
            _serviceName,
            context.InputAddress,
            context.TransportHeaders.Get<string>("MessageId")
        );
        return Task.CompletedTask;
    }

    public Task PreConsume<T>(ConsumeContext<T> context) where T : class
    {
        _logger.LogInformation(
            "MT_OBSERVER_CONSUME_PRE service={ServiceName} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }

    public Task PostConsume<T>(ConsumeContext<T> context, TimeSpan duration, string consumerType) where T : class
    {
        _logger.LogInformation(
            "MT_OBSERVER_CONSUME_POST service={ServiceName} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId} durationMs={DurationMs} consumerType={ConsumerType}",
            _serviceName,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId,
            duration.TotalMilliseconds,
            consumerType
        );
        return Task.CompletedTask;
    }

    public Task ConsumeFault<T>(ConsumeContext<T> context, TimeSpan duration, string consumerType, Exception exception) where T : class
    {
        _logger.LogError(
            exception,
            "MT_OBSERVER_CONSUME_FAULT service={ServiceName} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId} durationMs={DurationMs} consumerType={ConsumerType}",
            _serviceName,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId,
            duration.TotalMilliseconds,
            consumerType
        );
        return Task.CompletedTask;
    }

    public Task PreSend<T>(SendContext<T> context) where T : class
    {
        _logger.LogInformation(
            "MT_OBSERVER_SEND_PRE service={ServiceName} processId={ProcessId} destination={DestinationAddress} messageType={MessageType} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            _processId,
            context.DestinationAddress,
            string.Join(',', context.SupportedMessageTypes),
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }

    public Task PostSend<T>(SendContext<T> context) where T : class
    {
        _logger.LogInformation(
            "MT_OBSERVER_SEND_POST service={ServiceName} processId={ProcessId} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            _processId,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }

    public Task SendFault<T>(SendContext<T> context, Exception exception) where T : class
    {
        _logger.LogError(
            exception,
            "MT_OBSERVER_SEND_FAULT service={ServiceName} processId={ProcessId} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            _processId,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }

    public Task PrePublish<T>(PublishContext<T> context) where T : class
    {
        _logger.LogInformation(
            "MT_OBSERVER_PUBLISH_PRE service={ServiceName} processId={ProcessId} destination={DestinationAddress} messageType={MessageType} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            _processId,
            context.DestinationAddress,
            string.Join(',', context.SupportedMessageTypes),
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }

    public Task PostPublish<T>(PublishContext<T> context) where T : class
    {
        _logger.LogInformation(
            "MT_OBSERVER_PUBLISH_POST service={ServiceName} processId={ProcessId} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            _processId,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }

    public Task PublishFault<T>(PublishContext<T> context, Exception exception) where T : class
    {
        _logger.LogError(
            exception,
            "MT_OBSERVER_PUBLISH_FAULT service={ServiceName} processId={ProcessId} destination={DestinationAddress} requestId={RequestId} correlationId={CorrelationId} messageId={MessageId}",
            _serviceName,
            _processId,
            context.DestinationAddress,
            context.RequestId,
            context.CorrelationId,
            context.MessageId
        );
        return Task.CompletedTask;
    }
}
